require "rails_helper"

RSpec.describe "Billing portal", type: :request do
  it "redirects an anonymous visitor to sign in" do
    post billing_portal_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "redirects a signed-in user with no Stripe customer yet back to their account with a message" do
    user = create(:user, stripe_customer_id: nil)
    sign_in user

    post billing_portal_path

    expect(response).to redirect_to(account_path)
    expect(flash[:alert]).to match(/no card payments yet/i)
  end

  it "redirects a signed-in user with a real Stripe customer to a real Stripe-hosted portal session",
     vcr: { cassette_name: "billing_portal/real_session" } do
    user = create(:user, stripe_customer_id: "cus_Uud9RM6zxXLk2p")
    sign_in user

    post billing_portal_path

    expect(response).to redirect_to(a_string_starting_with("https://billing.stripe.com/"))
  end
end
