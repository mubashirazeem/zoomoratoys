class HomeController < ApplicationController
  def index
    @best_selling_grid = Product.includes(:product_variants, images_attachments: :blob).ordered.limit(12)
    @new_arrivals = Product.includes(:product_variants, images_attachments: :blob).newest_first.limit(20)
    @featured_products = Product.includes(:product_variants, images_attachments: :blob).featured.ordered.limit(8)
    @promotional_banners = PromotionalBanner.active.ordered.includes(image_attachment: :blob)
  end
end
