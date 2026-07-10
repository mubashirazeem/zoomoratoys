# frozen_string_literal: true

# Full-bleed hero slider built as a true 3D perspective cube (real
# rotateY/translateZ geometry, not a faked crossfade) — slides physically
# turn to face the camera. Each face carries a Ken Burns zoom and a
# staggered text reveal on its own floating Z-depth layer, and the whole
# scene tilts gently toward the cursor. Prev/next arrows and a full-width
# segmented progress bar (doubling as a scrubber) sit flat above the 3D
# scene. Autoplay pauses on hover/focus; touch users can swipe. Every
# headline/CTA is live, semantic HTML — no text baked into the imagery (see
# ACCESSIBILITY_GUIDELINES.md). Original copy and placeholder photography
# throughout.
#
# slides: an ordered array of hashes with keys:
#   :image (asset filename), :eyebrow, :headline, :cta_label, :cta_url
class Marketing::HeroComponent < ViewComponent::Base
  def initialize(slides:)
    @slides = slides
  end

  attr_reader :slides
end
