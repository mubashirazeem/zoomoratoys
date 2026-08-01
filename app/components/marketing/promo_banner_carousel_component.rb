# frozen_string_literal: true

# One full-width promotional banner visible at a time, auto-advancing to
# the next after a few seconds — the same "changes after a while" idea as
# the hero, just a plain crossfade rather than its 3D cube. See
# app/javascript/controllers/promo_banner_slideshow_controller.js.
#
# Each slide is a real Marketing::CtaBannerComponent (the same full-width
# card already used elsewhere on the page) — this component only handles
# showing one at a time and cycling between them, not the card look itself.
class Marketing::PromoBannerCarouselComponent < ViewComponent::Base
  Banner = Struct.new(:title, :description, :cta_label, :cta_url, :tone, keyword_init: true)

  def initialize(banners:)
    @banners = banners.map { |attrs| Banner.new(**attrs) }
  end

  attr_reader :banners
end
