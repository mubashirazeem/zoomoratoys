# frozen_string_literal: true

# Sets which currency ApplicationHelper#format_price displays prices in —
# see that helper and ExchangeRate for the rest. This never touches an
# Order, a Cart, or Stripe: the cookie only ever changes what a page
# *shows*, matching the checkout page's own disclaimer that the real
# charge stays AED regardless.
class CurrenciesController < ApplicationController
  def update
    if ApplicationHelper::DISPLAY_CURRENCIES.include?(params[:code])
      cookies[:currency] = { value: params[:code], expires: 1.year, httponly: true }
    end

    redirect_back fallback_location: root_path
  end
end
