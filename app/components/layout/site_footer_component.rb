# frozen_string_literal: true

# categories: passed in from ApplicationController's before_action (see
# RAILS_GUIDELINES.md) — this component never queries the database itself.
# SUPPORT_PHONE is real (client-provided, 2026-08-05). SUPPORT_EMAIL is real
# too (client-provided, 2026-08-16). The footer's street address is still a
# placeholder pending real business information; tracked in
# DEVELOPMENT_PROGRESS.md.
class Layout::SiteFooterComponent < ViewComponent::Base
  SUPPORT_EMAIL = "sales@zoomora.com"
  SUPPORT_PHONE = "+971 52 722 5064"

  def initialize(categories: [])
    @categories = categories
  end

  attr_reader :categories

  def current_year
    Date.current.year
  end
end
