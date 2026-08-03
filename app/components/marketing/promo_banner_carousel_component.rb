# frozen_string_literal: true

# One full-width, photo-backed promotional banner visible at a time,
# auto-advancing to the next after a few seconds — the same "changes after
# a while" idea as the hero, just a plain crossfade rather than its 3D cube.
# See app/javascript/controllers/promo_banner_slideshow_controller.js.
#
# Renders real PromotionalBanner records (admin-managed — see
# Admin::PromotionalBannersController), never queries itself (see
# COMPONENT_GUIDELINES.md).
class Marketing::PromoBannerCarouselComponent < ViewComponent::Base
  def initialize(banners:)
    # Normalized to a real Array once here — the template calls
    # each_index/each_with_index, which ActiveRecord::Relation (what the
    # real controller passes) doesn't support directly.
    @banners = banners.to_a
  end

  attr_reader :banners
end
