# frozen_string_literal: true

# The "heading + optional view-all link" pattern used above every product
# rail and section. One implementation, used everywhere — see
# UI_UX_GUIDELINES.md's "one see-more pattern" rule. Accepts an optional
# `actions` slot for extra controls that belong in the same row (e.g. a
# carousel's prev/next buttons in Marketing::ProductRailComponent).
class Marketing::SectionHeadingComponent < ViewComponent::Base
  renders_one :actions

  def initialize(title:, view_all_url: nil, view_all_label: "View All")
    @title = title
    @view_all_url = view_all_url
    @view_all_label = view_all_label
  end

  attr_reader :title, :view_all_url, :view_all_label

  def view_all?
    view_all_url.present?
  end
end
