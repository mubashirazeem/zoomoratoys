# frozen_string_literal: true

# A continuously, sideways-scrolling promotional strip — distinct from the
# static, dismissable announcement bar in Layout::SiteHeaderComponent (which
# appears site-wide). This is a home-page-only element. Purely decorative/
# supplementary: every message here is also available as static, accessible
# content elsewhere on the page (the announcement bar, the promotional
# banners), so the moving track itself is hidden from screen readers
# (aria-hidden) rather than requiring its own pause control — see
# ACCESSIBILITY_GUIDELINES.md. Respects prefers-reduced-motion (see
# layouts/_head.html.erb), freezing in place rather than animating.
class Marketing::PromoMarqueeComponent < ViewComponent::Base
  MESSAGES = [
    "Free UAE Delivery & Installation",
    "Buy Now, Pay Later Available",
    "12-Month Manufacturer Warranty",
    "Adventure Starts Here"
  ].freeze
end
