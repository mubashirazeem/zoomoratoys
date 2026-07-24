# spec/stripe_configuration_spec.rb
require "rails_helper"

RSpec.describe "Stripe configuration" do
  it "has a real API key configured" do
    expect(Stripe.api_key).to be_present
  end

  it "can reach Stripe's real test-mode API", vcr: { cassette_name: "stripe_configuration/account_retrieve" } do
    account = Stripe::Account.retrieve
    expect(account.id).to be_present
  end
end
