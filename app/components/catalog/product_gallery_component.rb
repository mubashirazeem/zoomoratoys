# frozen_string_literal: true

# Product detail gallery: a large main image plus a thumbnail strip that
# swaps it. Uses real admin-uploaded photos when a product has them;
# falls back to the shared category photo (repeated across the thumbnail
# strip) for products nobody has photographed yet — an honest placeholder,
# not a fake multi-angle gallery.
class Catalog::ProductGalleryComponent < ViewComponent::Base
  THUMBNAIL_COUNT = 4
  MAIN_VARIANT = { resize_to_limit: [ 800, 800 ] }.freeze
  THUMB_VARIANT = { resize_to_limit: [ 200, 200 ] }.freeze
  # Meaningfully sharper than MAIN_VARIANT — the hover lens and lightbox
  # need real extra detail to zoom into, not just the display image scaled
  # up (which would just look blurry).
  ZOOM_VARIANT = { resize_to_limit: [ 1600, 1600 ] }.freeze

  def initialize(product:, badge: nil)
    @product = product
    @badge = badge
  end

  attr_reader :product, :badge

  # [{ thumb:, full:, zoom: }, ...] — all three are the same fallback path
  # when there's no real photo yet, or thumb/display/zoom variant sizes of
  # the same real upload otherwise.
  def gallery_items
    if product.images.attached?
      product.images.map { |image| { thumb: image.variant(THUMB_VARIANT), full: image.variant(MAIN_VARIANT), zoom: image.variant(ZOOM_VARIANT) } }
    else
      Array.new(THUMBNAIL_COUNT) { { thumb: fallback_image, full: fallback_image, zoom: fallback_image } }
    end
  end

  def main_image
    gallery_items.first[:full]
  end

  def main_zoom_image
    gallery_items.first[:zoom]
  end

  # Active Storage variants need url_for; a bare asset filename (the
  # fallback path) needs image_path instead — url_for doesn't resolve
  # plain asset pipeline paths correctly.
  def full_src(item)
    resolve_src(item[:full])
  end

  def zoom_src(item)
    resolve_src(item[:zoom])
  end

  private

  def resolve_src(source)
    source.is_a?(String) ? helpers.image_path(source) : url_for(source)
  end

  def fallback_image
    "category-#{product.placeholder_key}.jpg"
  end
end
