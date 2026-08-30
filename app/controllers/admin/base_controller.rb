# frozen_string_literal: true

# Every admin controller inherits from here — the single place the
# authentication gate lives, so it can't be forgotten on a new controller.
# Inherits directly from ActionController::Base, not ApplicationController:
# the customer-site before_actions (nav categories, cart, wishlist count)
# have no meaning in the admin panel and would just be wasted queries.
class Admin::BaseController < ActionController::Base
  layout "admin"
  protect_from_forgery with: :exception

  before_action :authenticate_admin_user!
  before_action :set_paper_trail_whodunnit
  before_action -> { @robots_noindex = true }

  private

  def user_for_paper_trail
    current_admin_user&.id
  end

  # Coupons, Sales Reports, and Admin Users management are Owner-only —
  # each of those controllers adds this as its own before_action. Not
  # applied globally here: most of the admin panel (Products, Orders, etc.)
  # is meant for Staff too.
  def require_owner!
    return if current_admin_user.owner?

    redirect_to admin_root_path, alert: "That page is only available to owners."
  end
end
