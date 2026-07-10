# frozen_string_literal: true

# categories: passed in from ApplicationController's before_action (see
# RAILS_GUIDELINES.md) — this component never queries the database itself.
# Contact details below are placeholders pending real business information;
# tracked in DEVELOPMENT_PROGRESS.md.
class Layout::SiteFooterComponent < ViewComponent::Base
  SUPPORT_EMAIL = "hello@zoomora.com"
  SUPPORT_PHONE = "+971 4 000 0000"

  def initialize(categories: [])
    @categories = categories
  end

  attr_reader :categories

  def current_year
    Date.current.year
  end
end
