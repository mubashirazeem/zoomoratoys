class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_nav_categories
  before_action :set_cart
  before_action :set_wishlist_count
  before_action :configure_permitted_parameters, if: :devise_controller?

  private

  # Devise's registration form only permits :email/:password by default —
  # first_name/last_name are Zoomora-specific additions (see the
  # DeviseCreateUsers migration), so they need to be added explicitly.
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name ])
  end

  # Global site chrome (footer "Shop by Category" links, header mega-menu)
  # needs the category list on every page. Loaded once here, per
  # RAILS_GUIDELINES.md's "no query logic inside a component" rule —
  # components receive this as data, they never fetch it themselves.
  #
  # @nav_category_products backs the header mega-menu's "popular in…" column:
  # up to three products per nav category, built from a single grouped query.
  def set_nav_categories
    @nav_categories = Category.ordered.to_a
    @nav_category_products =
      Product.where(category_id: @nav_categories.map(&:id)).ordered
             .group_by(&:category_id)
             .transform_values { |products| products.first(3) }
  end

  # Global site chrome (header cart badge + mini-cart drawer) needs the cart
  # contents on every page, not just /cart. No session or database-backed
  # cart yet (see PROJECT_VISION.md non-goals) — CartsController::
  # DEMO_ITEM_SLUGS is the single fixed demo set shown everywhere until the
  # real backend lands.
  def set_cart
    @cart_products = Product.includes(:category).where(slug: CartsController::DEMO_ITEM_SLUGS)
    @cart_item_count = @cart_products.size
    @cart_suggested_products = Product.includes(:category)
                                       .featured
                                       .where.not(slug: CartsController::DEMO_ITEM_SLUGS)
                                       .ordered
                                       .limit(3)
  end

  # Header wishlist badge count — matches WishlistsController::
  # DEMO_ITEM_SLUGS, same placeholder pattern as the cart badge.
  def set_wishlist_count
    @wishlist_item_count = WishlistsController::DEMO_ITEM_SLUGS.size
  end
end
