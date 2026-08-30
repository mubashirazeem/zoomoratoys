# frozen_string_literal: true

# The slide-in drawer panel controlled by the nav-drawer Stimulus
# controller (see Layout::SiteHeaderComponent, which renders this inside
# the same data-controller scope).
class Layout::MobileNavComponent < ViewComponent::Base
  def initialize(items:, current_user: nil)
    @items = items
    @current_user = current_user
  end

  attr_reader :items, :current_user

  def signed_in?
    current_user.present?
  end
end
