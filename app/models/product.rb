# frozen_string_literal: true

class Product < ApplicationRecord
  include ImageAttachmentValidatable

  has_paper_trail

  belongs_to :category
  # A product that's ever been ordered must never be deletable — that's
  # real order history, not a live/mutable reference. Without this, calling
  # destroy on a sold product raised a raw, unhandled
  # ActiveRecord::InvalidForeignKey (confirmed reproducible) instead of a
  # normal validation-style error the admin UI already knows how to show.
  has_many :line_items, dependent: :restrict_with_error
  # Cart/wishlist entries are live, mutable references, not history — a
  # deleted product should simply disappear from them, same as if it went
  # out of stock; same reasoning and same InvalidForeignKey risk as above.
  has_many :cart_items, dependent: :destroy
  has_many :wishlist_items, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :product_views, dependent: :destroy
  has_many :product_variants, dependent: :destroy
  # Real, admin-uploaded photos — falls back to the shared category photo
  # (see Catalog::ProductGalleryComponent) for products an admin hasn't
  # uploaded real images for yet.
  has_many_attached :images

  enum :stock_status, { in_stock: "in_stock", sold_out: "sold_out", preorder: "preorder" },
       default: "in_stock", validate: true

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :sku, presence: true, uniqueness: true
  validates :price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :placeholder_key, presence: true, inclusion: { in: Category::PLACEHOLDER_KEYS }
  validates :stock_quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates_image_attachment :images, max_count: 12
  validate :compare_at_price_must_exceed_price

  before_validation :assign_slug, on: :create
  # Keeps stock_status in step with stock_quantity on a normal save (e.g. an
  # admin editing stock in the product form). Never touches "preorder" — a
  # deliberate manual merchandising state independent of the real count.
  # Also backs off whenever stock_status is *itself* being explicitly set in
  # the same save (e.g. an admin deliberately pausing sales at 10 units
  # in stock) — auto-derivation only kicks in when stock_quantity changes on
  # its own and stock_status wasn't touched. Order.create_from_cart!/
  # #restore_stock! change stock_quantity via decrement!/increment!, which
  # bypass callbacks entirely (atomic counter updates by design) — see
  # #sync_stock_status! for that path instead.
  before_save :sync_stock_status_from_quantity, if: -> { stock_quantity_changed? && !stock_status_changed? }

  scope :ordered, -> { order(:position, :name) }
  scope :featured, -> { where(featured: true) }
  scope :best_sellers, -> { where(best_seller: true) }
  scope :newest_first, -> { order(created_at: :desc) }

  # Real Shop page search — name/description/sku, case-insensitive. Uses a
  # bound parameter (never string-interpolated SQL, see RAILS_GUIDELINES.md)
  # and escapes the query's own %/_ characters so a literal search for e.g.
  # "50%" doesn't get reinterpreted as a SQL LIKE wildcard.
  scope :search, ->(query) {
    pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
    # Table-qualified — an unqualified "name ILIKE" was ambiguous the moment
    # any query joined in another table with its own name column (e.g.
    # ActiveStorage::Attachment has one), confirmed reproducible via
    # Product.includes(images_attachments: :blob).search(...).pluck(:id).
    where("products.name ILIKE :pattern OR products.description ILIKE :pattern OR products.sku ILIKE :pattern", pattern: pattern)
  }

  scope :price_between, ->(min_cents, max_cents) { where(price_cents: min_cents..max_cents) }

  # Products that have at least one real variant matching one of the given
  # Color option values — real data (ProductVariant#options), not the old
  # fixed hex-swatch grid that had no data behind it at all.
  scope :with_variant_color, ->(colors) {
    joins(:product_variants).where("product_variants.options ->> 'Color' IN (?)", colors).distinct
  }

  def self.sorted_by(key)
    case key
    when "price_asc" then order(price_cents: :asc)
    when "price_desc" then order(price_cents: :desc)
    when "newest" then newest_first
    else ordered
    end
  end

  # Real distinct Color values across every variant in the catalog — backs
  # the Shop page's Color filter. Callable on a scoped relation (e.g.
  # `@products.available_variant_colors`, same delegation pattern as
  # .sorted_by above) so the list only shows colors that actually belong to
  # products in the current category/search/etc — calling it on the bare
  # `Product` class instead would list every color in the whole catalog
  # regardless of what page you're on, which is exactly the bug this scoping
  # fixes (confirmed live: a 400+-item list of irrelevant colors showing on
  # every category page once real variants existed).
  def self.available_variant_colors
    # unscope(:includes) matters: plain `pluck(:id)` on a relation carrying
    # ProductsController#index's `.includes(:product_variants, ...)` forces
    # Rails to route through a full 3-table join-dependency JOIN just to
    # pluck ids (has_include? routes any pluck/calculate through
    # apply_join_dependency whenever includes_values is present) — measured
    # at ~291ms on a 1,178-product catalog. A subquery scoped to just `id`
    # needs none of that.
    ProductVariant.where(product_id: unscope(:includes, :order).select(:id))
                  .pluck(Arel.sql("options ->> 'Color'")).compact.uniq.sort
  end

  def to_param
    slug
  end

  def average_rating
    @average_rating ||= reviews.average(:rating)&.round(1)
  end

  # Virtual attribute so the admin form can work in whole AED (a decimal
  # amount a human types), while the stored value stays a correctness-safe
  # integer — see DATABASE_GUIDELINES.md's "money is always an integer"
  # rule. The float only ever exists transiently at the form-input layer.
  def price
    price_cents && (price_cents / 100.0)
  end

  def price=(value)
    self.price_cents = (value.to_f * 100).round if value.present?
  end

  # Same virtual-attribute pattern as price/price= above — admin types a
  # whole AED "was" price, storage stays an integer. Only present at all
  # when the admin has set a genuine reduced price to sell at; there is no
  # fabricated/simulated discount anywhere in this app.
  def compare_at_price
    compare_at_price_cents && (compare_at_price_cents / 100.0)
  end

  # Unlike price= above, blank must actually clear the column — ending a
  # sale (going from "on sale" back to regular price) means unsetting this,
  # not leaving the previous value untouched.
  def compare_at_price=(value)
    self.compare_at_price_cents = value.present? ? (value.to_f * 100).round : nil
  end

  def on_sale?
    compare_at_price_cents.present? && compare_at_price_cents > price_cents
  end

  def discount_percent
    return unless on_sale?

    (100 - (price_cents * 100.0 / compare_at_price_cents)).round
  end

  def has_variants?
    product_variants.any?
  end

  # Explicit counterpart to the before_save callback below, for the two call
  # sites that change stock_quantity via decrement!/increment!
  # (Order.create_from_cart!, Order#restore_stock!) — those bypass
  # ActiveRecord callbacks by design, so the callback never fires for them.
  def sync_stock_status!
    return if preorder?

    correct_status = stock_quantity.to_i.positive? ? "in_stock" : "sold_out"
    update_column(:stock_status, correct_status) if stock_status != correct_status
  end

  # Whether this product can genuinely be added to cart right now. For a
  # product with variants, stock lives per-variant (see
  # Order.create_from_cart!'s decrement logic) — the parent's own
  # stock_quantity/stock_status are irrelevant in that case, so this checks
  # every variant instead. For a plain product, stock_status (kept in sync
  # with stock_quantity above) is the answer directly.
  def out_of_stock?
    return product_variants.none?(&:in_stock?) if has_variants?

    sold_out?
  end

  # The real admin-uploaded photo (as a variant, resized per call site) when
  # one exists, otherwise the shared category placeholder path — the single
  # place this fallback decision is made, so every view (grid cards, cart,
  # checkout, header mega-menu, sticky bar) shows the same real photo the
  # moment one's uploaded, instead of each duplicating this check.
  def display_photo(**variant_options)
    return images.first.variant(**variant_options) if images.attached?

    "category-#{placeholder_key}.jpg"
  end

  # Option keys in first-seen order across this product's variants — e.g.
  # ["Color", "Size"]. Free-form, not fixed to Color/Size/Material: whatever
  # labels the admin actually used when defining variants.
  def variant_option_types
    product_variants.each_with_object([]) { |variant, keys| keys.concat(variant.options.keys - keys) }
  end

  # Distinct values for one option type, in first-seen order — e.g.
  # variant_option_values("Color") => ["Racing Red", "Midnight Black"].
  def variant_option_values(option_type)
    product_variants.each_with_object([]) { |variant, values| values << variant.options[option_type] unless values.include?(variant.options[option_type]) }
                     .compact
  end

  private

  def assign_slug
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end

  def sync_stock_status_from_quantity
    return if preorder?

    self.stock_status = stock_quantity.to_i.positive? ? "in_stock" : "sold_out"
  end

  def compare_at_price_must_exceed_price
    return if compare_at_price_cents.blank? || price_cents.blank?

    errors.add(:compare_at_price_cents, "must be greater than the price for a real discount") if compare_at_price_cents <= price_cents
  end
end
