class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_nav_categories

  private

  # Global site chrome (footer "Shop by Category" links) needs the category
  # list on every page. Loaded once here, per RAILS_GUIDELINES.md's "no
  # query logic inside a component" rule — components receive this as data,
  # they never fetch it themselves.
  def set_nav_categories
    @nav_categories = Category.ordered
  end
end
