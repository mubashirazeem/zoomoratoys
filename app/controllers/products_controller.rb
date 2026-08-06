class ProductsController < ApplicationController
  PER_PAGE = 24
  ALLOWED_PER_PAGE = [ 12, 24, 48 ].freeze

  def index
    @categories = @nav_categories
    @selected_category = @categories.find { |category| category.slug == params[:category] }

    @products = Product.includes(:product_variants, images_attachments: :blob).sorted_by(params[:sort])
    @products = @products.where(category: @selected_category) if @selected_category
    @products = @products.search(params[:q]) if params[:q].present?
    @products = @products.where(stock_status: availability_filter) if availability_filter.present?
    @products = @products.price_between(min_price_cents, max_price_cents) if min_price_cents || max_price_cents

    # Computed from the category/search/availability/price-scoped relation,
    # but BEFORE the color filter itself is applied — so checking one color
    # never makes another still-valid color vanish from the list (standard
    # faceted-search behavior, same as Amazon/Shopify's own filters).
    @available_variant_colors = @products.available_variant_colors

    @products = @products.with_variant_color(color_filter) if color_filter.present?
    @products = @products.page(params[:page]).per(per_page)
  end

  def show
    @product = Product.includes(:category, images_attachments: :blob).find_by!(slug: params[:slug])
    ProductView.record!(product: @product, viewer_token: viewer_token)
    @current_viewers = ProductView.current_count_for(@product)
    @reviews = @product.reviews.includes(:user).newest_first
    @related_products = Product.includes(:product_variants, images_attachments: :blob)
                                .where(category: @product.category)
                                .where.not(id: @product.id)
                                .ordered
                                .limit(3)
    # Backed by this visitor's own ProductView rows (viewer_token), not just
    # the newest catalog products — "Recently Viewed" was previously showing
    # the same 3 newest products to every visitor regardless of what they'd
    # actually looked at.
    recently_viewed_ids = ProductView.where(viewer_token: viewer_token)
                                      .where.not(product_id: @product.id)
                                      .order(updated_at: :desc)
                                      .limit(3)
                                      .pluck(:product_id)
    @recently_viewed = Product.includes(:product_variants, images_attachments: :blob)
                               .where(id: recently_viewed_ids)
                               .index_by(&:id)
                               .values_at(*recently_viewed_ids)
                               .compact
  end

  private

  # A dedicated signed cookie rather than Rails' own session id: the
  # session id is nil until something else happens to write to the
  # session first, which this feature can't rely on. No PII — just an
  # opaque, anonymous per-browser identifier for the "N viewing now" count.
  def viewer_token
    cookies.signed[:viewer_token] ||= SecureRandom.uuid
  end

  def availability_filter
    Array(params[:availability]).select { |value| Product.stock_statuses.key?(value) }
  end

  def color_filter
    Array(params[:colors]).reject(&:blank?)
  end

  # Whole AED typed into the form → cents, same conversion Product#price=
  # already uses — this catalog's price points have no fractional AED (see
  # DATABASE_GUIDELINES.md). nil (not 0/Infinity) when absent, so the range
  # passed to `price_between` is properly beginless/endless rather than a
  # fake sentinel value landing in a SQL query against an integer column.
  def min_price_cents
    params[:min_price].presence&.to_i&.then { |aed| aed * 100 }
  end

  def max_price_cents
    params[:max_price].presence&.to_i&.then { |aed| aed * 100 }
  end

  def per_page
    candidate = params[:per_page].to_i
    ALLOWED_PER_PAGE.include?(candidate) ? candidate : PER_PAGE
  end
end
