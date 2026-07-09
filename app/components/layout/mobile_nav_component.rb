# frozen_string_literal: true

# The slide-in drawer panel controlled by the nav-drawer Stimulus
# controller (see Layout::SiteHeaderComponent, which renders this inside
# the same data-controller scope).
class Layout::MobileNavComponent < ViewComponent::Base
  def initialize(items:)
    @items = items
  end

  attr_reader :items
end
