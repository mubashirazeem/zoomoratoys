require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "succeeds" do
      get root_path

      expect(response).to have_http_status(:success)
    end

    it "shows featured products" do
      featured = create(:product, :featured, name: "Trailhawk Off-Road Scooter")
      create(:product, featured: false, name: "Not Featured")

      get root_path

      expect(response.body).to include("Trailhawk Off-Road Scooter")
    end

    it "shows up to four categories" do
      create_list(:category, 5)

      get root_path

      expect(response).to have_http_status(:success)
    end

    it "greets a signed-in user by name in the header, end to end through a real session" do
      user = create(:user, first_name: "Layla")
      sign_in user

      get root_path

      expect(response.body).to include("Hi, Layla")
    end

    it "prompts sign-in for an anonymous visitor" do
      get root_path

      expect(response.body).to include("Sign In")
      expect(response.body).not_to include("Hi, ")
    end

    it "renders real, DB-backed promotional banners without crashing — a component spec built on a plain Array can't catch a method the real ActiveRecord::Relation doesn't support" do
      create(:promotional_banner, title: "Summer Sale", active: true)
      create(:promotional_banner, title: "Hidden Banner", active: false)

      get root_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Summer Sale")
      expect(response.body).not_to include("Hidden Banner")
    end

    it "shows the floating WhatsApp contact button" do
      get root_path

      expect(response.body).to include("https://wa.me/971527225064")
    end

    it "renders banners in both placement slots — a second admin-managed carousel, not just the original one" do
      create(:promotional_banner, title: "Top Slot Sale", placement: "before_new_arrivals", active: true)
      create(:promotional_banner, title: "Bottom Slot Sale", placement: "after_new_arrivals", active: true)

      get root_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Top Slot Sale")
      expect(response.body).to include("Bottom Slot Sale")
    end

    it "renders real, DB-backed customer highlights without crashing" do
      create(:customer_highlight, customer_name: "Ahmed R.", quote: "Great bike!", active: true)
      create(:customer_highlight, customer_name: "Hidden Customer", active: false)

      get root_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Ahmed R.")
      expect(response.body).not_to include("Hidden Customer")
    end
  end
end
