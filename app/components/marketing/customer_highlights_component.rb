# frozen_string_literal: true

# Homepage "Happy Customers" rail — real delivered-product photos and
# reviews, admin-curated (see CustomerHighlight; Admin::CustomerHighlightsController).
# Same horizontally-scrollable rail pattern as Marketing::ProductRailComponent,
# reusing the same carousel Stimulus controller. Hides itself entirely
# rather than show a hollow section before any highlights exist — same
# convention as Marketing::ReviewsComponent.
class Marketing::CustomerHighlightsComponent < ViewComponent::Base
  def initialize(highlights: CustomerHighlight.none)
    @highlights = highlights
  end

  attr_reader :highlights

  def render?
    highlights.any?
  end
end
