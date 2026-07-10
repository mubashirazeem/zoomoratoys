# frozen_string_literal: true

# Homepage "About Zoomora" band: brand-story copy, a photo with a layered
# offset card behind it, and a floating tactile stat badge — reusing the
# site's raised-bevel "3D" language (see .brand-badge/.brand-chip in the
# layout head) instead of a plain text block. Links through to the full
# About page for the rest of the story. Original copy and placeholder
# photography throughout.
class Marketing::BrandStoryComponent < ViewComponent::Base
  def category_count
    Category::PLACEHOLDER_KEYS.size
  end
end
