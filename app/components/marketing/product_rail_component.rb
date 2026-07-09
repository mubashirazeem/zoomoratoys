# frozen_string_literal: true

# A horizontally-scrollable row of products with prev/next controls —
# "Best Sellers," "New Arrivals," "Featured Picks," etc. all use this same
# component. Receives fully-loaded Products; never queries itself (see
# COMPONENT_GUIDELINES.md).
class Marketing::ProductRailComponent < ViewComponent::Base
  def initialize(title:, products:, view_all_url: nil, view_all_label: "View All")
    @title = title
    @products = products
    @view_all_url = view_all_url
    @view_all_label = view_all_label
  end

  attr_reader :title, :products, :view_all_url, :view_all_label
end
