class HomeController < ApplicationController
  def index
    @best_selling_grid = Product.includes(:product_variants, images_attachments: :blob).ordered.limit(12)
    @new_arrivals = Product.includes(:product_variants, images_attachments: :blob).newest_first.limit(8)
    @featured_products = Product.includes(:product_variants, images_attachments: :blob).featured.ordered.limit(8)
    @featured_categories = @nav_categories.first(4)
  end
end
