# frozen_string_literal: true

# Redirects a signed-in user to a real Stripe-hosted Billing Portal session
# so they can view invoices/receipts for their card payments. Only relevant
# for users who've actually paid by card at least once — Payments::CreateCardOrder
# (see Task 4) is what populates User#stripe_customer_id on first card checkout,
# so most users won't have one yet.
class BillingPortalController < ApplicationController
  before_action :authenticate_user!

  def create
    if current_user.stripe_customer_id.blank?
      redirect_to account_path, alert: "You have no card payments yet."
      return
    end

    session = Stripe::BillingPortal::Session.create(customer: current_user.stripe_customer_id, return_url: account_url)
    redirect_to session.url, allow_other_host: true
  end
end
