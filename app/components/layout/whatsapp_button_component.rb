# frozen_string_literal: true

# Floating WhatsApp contact bubble, rendered once in the layout and shown
# on every customer-facing page (see application.html.erb). Not shown in
# the admin layout — that's an internal tool, not a support surface.
class Layout::WhatsappButtonComponent < ViewComponent::Base
  PHONE_NUMBER = "971527225064"
  WHATSAPP_URL = "https://wa.me/#{PHONE_NUMBER}"
end
