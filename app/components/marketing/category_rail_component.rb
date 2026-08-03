# frozen_string_literal: true

# A horizontally-scrollable row of category tiles — same rail mechanic as
# Marketing::ProductRailComponent (prev/next controls, drag-to-scroll),
# used on the home page so every category is reachable, not just a few
# featured ones (client feedback, 2026-08-02: "make like a slide of
# categories pictures move sideways... showing all the categories").
# Receives fully-loaded Categories; never queries itself (see
# COMPONENT_GUIDELINES.md).
class Marketing::CategoryRailComponent < ViewComponent::Base
  def initialize(title:, categories:, view_all_url: nil, view_all_label: "View All")
    @title = title
    @categories = categories
    @view_all_url = view_all_url
    @view_all_label = view_all_label
  end

  attr_reader :title, :categories, :view_all_url, :view_all_label
end
