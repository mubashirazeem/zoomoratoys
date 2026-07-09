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
  end
end
