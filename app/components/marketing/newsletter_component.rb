# frozen_string_literal: true

# Homepage/footer-adjacent email capture. Submits to a real
# NewsletterSubscriber record (see NewsletterSubscribersController) — not a
# decorative dead form.
class Marketing::NewsletterComponent < ViewComponent::Base
  def initialize(title: "Join the Adventure", description: "Get new arrivals, restocks, and seasonal offers in your inbox.")
    @title = title
    @description = description
  end

  attr_reader :title, :description
end
