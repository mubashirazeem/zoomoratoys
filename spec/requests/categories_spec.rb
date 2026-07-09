require "rails_helper"

RSpec.describe "Categories", type: :request do
  describe "GET /categories" do
    it "succeeds and lists every category" do
      category = create(:category, name: "Electric Scooters")

      get categories_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Electric Scooters")
    end
  end
end
