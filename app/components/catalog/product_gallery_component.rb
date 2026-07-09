# frozen_string_literal: true

# Product detail gallery: a large main image plus a thumbnail strip that
# swaps it. Milestone 1 has one real image per product (its category photo),
# so the thumbnails are placeholder repeats of that image — the structure is
# ready for true multi-angle photography without any view changes.
class Catalog::ProductGalleryComponent < ViewComponent::Base
  THUMBNAIL_COUNT = 4

  def initialize(product:, badge: nil)
    @product = product
    @badge = badge
  end

  attr_reader :product, :badge

  def image
    "category-#{product.placeholder_key}.jpg"
  end

  def thumbnails
    Array.new(THUMBNAIL_COUNT, image)
  end
end
