class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # AdminUser is a separate Devise scope with no meaning on the customer
  # site — its sign-in/password/unlock pages belong in the admin panel's
  # own chrome, not wrapped in the customer navbar/footer.
  layout :layout_by_resource

  before_action :merge_guest_cart_into_user_cart
  before_action :set_nav_categories
  before_action :set_cart
  before_action :set_wishlist_count
  before_action :configure_permitted_parameters, if: :devise_controller?

  private

  def layout_by_resource
    devise_controller? && resource_name == :admin_user ? "admin" : "application"
  end

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
  # up to three products per nav category. One small, indexed (category_id
  # is indexed), LIMIT-3 query per category — not one query that loads the
  # *entire* product catalog (with every image blob eager-loaded) just to
  # keep 3 rows and discard the rest, which is what this used to do and
  # which runs on every single customer-facing page, on every request.
  def set_nav_categories
    @nav_categories = Category.ordered.to_a
    @nav_category_products = @nav_categories.index_by(&:id).transform_values do |category|
      Product.includes(images_attachments: :blob).where(category_id: category.id).ordered.limit(3)
    end
  end

  # The real cart for whoever's making this request — a signed-in user's
  # own Cart, or an anonymous guest's, tracked by a signed cookie. Not
  # persisted until something is actually added (see persisted_cart) —
  # writing an empty Cart row for every mere pageview would be pure waste
  # at real traffic volume.
  def current_cart
    @current_cart ||= if user_signed_in?
      current_user.cart || Cart.new(user: current_user)
    elsif cookies.signed[:cart_token].present?
      Cart.find_by(guest_token: cookies.signed[:cart_token]) || Cart.new(guest_token: cookies.signed[:cart_token])
    else
      Cart.new
    end
  end
  helper_method :current_cart

  # Ensures current_cart is actually saved — called only from the mutation
  # path (CartItemsController), never from a plain page render. Assigns the
  # guest cookie at this point too, so a browsing visitor who never adds
  # anything never gets a cart cookie at all.
  def persisted_cart
    cart = current_cart
    return cart if cart.persisted?

    unless user_signed_in?
      cookies.signed[:cart_token] ||= { value: SecureRandom.uuid, expires: 30.days, httponly: true }
      cart.guest_token = cookies.signed[:cart_token]
    end
    cart.save!
    cart
  end
  helper_method :persisted_cart

  # Folds a just-signed-in visitor's guest cart into their real account cart
  # — runs on every request, but is a no-op the instant the guest cookie is
  # gone (which this itself clears the first time it actually merges
  # anything), so the steady-state cost is a single blank? check.
  def merge_guest_cart_into_user_cart
    return unless user_signed_in?

    token = cookies.signed[:cart_token]
    return if token.blank?

    Cart.merge_guest_into_user!(guest_token: token, user: current_user)
    cookies.delete(:cart_token)
  end

  # Global site chrome (header cart badge + mini-cart drawer) needs the real
  # cart contents on every page, not just /cart.
  def set_cart
    @cart_items = current_cart.persisted? ? current_cart.cart_items.includes(:product_variant, product: { images_attachments: :blob }) : []
    @cart_item_count = @cart_items.sum(&:quantity)
    @cart_subtotal_cents = @cart_items.sum(&:line_total_cents)
    @cart_suggested_products = Product.includes(:category, images_attachments: :blob)
                                       .featured
                                       .where.not(id: @cart_items.map(&:product_id))
                                       .ordered
                                       .limit(3)
  end

  # Header wishlist badge count, and the full set of wishlisted product ids
  # for this request — computed once here (a single query), never per-card
  # inside Catalog::ProductCardComponent (would be an N+1 on any grid page).
  # Guests don't have a wishlist (see WishlistsController — requires
  # sign-in, same as Account/Orders).
  def set_wishlist_count
    @wishlisted_product_ids = user_signed_in? ? current_user.wishlist_items.pluck(:product_id).to_set : Set.new
    @wishlist_item_count = @wishlisted_product_ids.size
  end
end
