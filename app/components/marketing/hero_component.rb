# frozen_string_literal: true

# Full-bleed hero slideshow: rotating banner slides with autoplay, prev/next
# arrows, and dot navigation. Every headline/CTA is live, semantic HTML — no
# text baked into the imagery (see ACCESSIBILITY_GUIDELINES.md). Original
# copy and placeholder photography throughout.
#
# slides: an ordered array of hashes with keys:
#   :image (asset filename), :eyebrow, :headline, :cta_label, :cta_url
class Marketing::HeroComponent < ViewComponent::Base
  def initialize(slides:)
    @slides = slides
  end

  attr_reader :slides
end
