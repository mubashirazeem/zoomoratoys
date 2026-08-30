# frozen_string_literal: true

# Floating click-to-call bubble, stacked directly above the WhatsApp bubble
# (see Layout::WhatsappButtonComponent) — same real phone number already
# used site-wide (Layout::SiteFooterComponent::SUPPORT_PHONE), just a tel:
# link instead of wa.me.
class Layout::CallButtonComponent < ViewComponent::Base
  def phone_number
    Layout::SiteFooterComponent::SUPPORT_PHONE
  end

  def tel_href
    "tel:#{phone_number.gsub(/\s+/, '')}"
  end
end
