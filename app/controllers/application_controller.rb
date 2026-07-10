class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_nav_categories

  private

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
end
