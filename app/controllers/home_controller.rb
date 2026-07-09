class HomeController < ApplicationController
  def index
    @best_selling_grid = Product.includes(:category).ordered.limit(15)
    @new_arrivals = Product.includes(:category).newest_first.limit(8)
    @featured_products = Product.includes(:category).featured.ordered.limit(8)
    @featured_categories = @nav_categories.first(4)
  end
end
