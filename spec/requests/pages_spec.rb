require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET /about" do
    it "succeeds" do
      get about_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Zoomora")
    end
  end
end
