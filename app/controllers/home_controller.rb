class HomeController < ApplicationController
  def index
    @best_selling_grid = Product.includes(:product_variants, images_attachments: :blob).best_sellers.ordered.limit(12)
    @new_arrivals = Product.includes(:product_variants, images_attachments: :blob).newest_first.limit(20)
    @featured_products = Product.includes(:product_variants, images_attachments: :blob).featured.ordered.limit(8)
    @promotional_banners_before_new_arrivals = PromotionalBanner.active.before_new_arrivals.ordered.includes(image_attachment: :blob)
    @promotional_banners_after_new_arrivals = PromotionalBanner.active.after_new_arrivals.ordered.includes(image_attachment: :blob)
    @review_count = Review.count
    @average_rating = Review.average(:rating)&.round(1)
    @featured_reviews = Review.includes(:user).order(rating: :desc, created_at: :desc).limit(Marketing::ReviewsComponent::FEATURED_COUNT)
    @customer_highlights = CustomerHighlight.active.ordered.includes(photo_attachment: :blob)
  end
end
