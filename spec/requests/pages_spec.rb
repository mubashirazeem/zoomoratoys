require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET /about" do
    it "succeeds" do
      get about_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Zoomora")
    end
  end

  describe "GET /faq" do
    it "succeeds and lists common questions" do
      get faq_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Frequently Asked Questions")
    end
  end

  describe "GET /privacy-policy" do
    it "succeeds" do
      get privacy_policy_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Privacy Policy")
    end
  end

  describe "GET /terms-and-conditions" do
    it "succeeds" do
      get terms_and_conditions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Terms")
    end
  end

  describe "GET /shipping-and-returns" do
    it "succeeds" do
      get shipping_and_returns_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Shipping")
    end
  end
end
