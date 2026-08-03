# frozen_string_literal: true

# Full-width promotional band (e.g. "Ready for your next adventure?").
# Replaces the reference site's flattened marketing-image banners with live,
# accessible HTML carrying the same bold visual weight.
class Marketing::CtaBannerComponent < ViewComponent::Base
  TONES = {
    dark: { bg: "bg-ink-950", title: "text-white", body: "text-grey-300", button: :primary },
    light: { bg: "bg-grey-50", title: "text-ink-950", body: "text-grey-600", button: :primary }
  }.freeze

  # (client feedback, 2026-08-03: this banner should also show pictures,
  # cycling via forward/back buttons, matching the promo banner carousel
  # elsewhere on the page.) Opt-in — only full_bleed usages pass photos.
  def initialize(title:, cta_label:, cta_url:, description: nil, tone: :dark, full_bleed: false, photos: [])
    raise ArgumentError, "unknown tone: #{tone.inspect}" unless TONES.key?(tone)

    @title = title
    @description = description
    @cta_label = cta_label
    @cta_url = cta_url
    @tone = TONES.fetch(tone)
    @full_bleed = full_bleed
    @photos = photos
  end

  attr_reader :title, :description, :cta_label, :cta_url, :tone, :full_bleed, :photos

  # Boxed/rounded card (existing default — FAQ, About) vs edge-to-edge like
  # the hero (client feedback, 2026-08-02/03: banners should be "100%" size
  # like the hero, not a smaller boxed card). Opt-in so existing usages
  # elsewhere on the site are unaffected. Height matches the hero/promo
  # carousel exactly once full_bleed, for the same "complete page" sizing.
  def wrapper_classes
    if full_bleed
      "#{tone[:bg]} relative overflow-hidden w-full flex flex-col items-center justify-center text-center px-[15px] h-[440px] md:h-[500px] lg:h-[560px]"
    else
      "#{tone[:bg]} rounded-[24px] px-6 py-14 lg:py-20 text-center"
    end
  end

  # Pauses autoplay on hover/focus — same interaction contract as the promo
  # banner carousel this pattern was copied from, so this slideshow doesn't
  # advance out from under someone reading it or aiming for an arrow.
  def wrapper_data
    return {} unless photos.any?

    {
      controller: "promo-banner-slideshow",
      action: "mouseenter->promo-banner-slideshow#stop mouseleave->promo-banner-slideshow#start " \
              "focusin->promo-banner-slideshow#stop focusout->promo-banner-slideshow#start"
    }
  end
end
