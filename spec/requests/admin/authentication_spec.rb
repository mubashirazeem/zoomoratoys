require "rails_helper"

RSpec.describe "Admin authentication", type: :request do
  describe "GET /admin" do
    it "redirects an anonymous visitor to the admin sign-in page" do
      get admin_root_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end

    it "does not show the customer-facing WhatsApp button on the admin sign-in page" do
      get new_admin_user_session_path

      expect(response.body).not_to include("wa.me")
    end

    it "redirects a signed-in customer — customer auth doesn't grant admin access" do
      sign_in create(:user)

      get admin_root_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end

    it "shows the dashboard for a signed-in admin" do
      sign_in create(:admin_user), scope: :admin_user

      get admin_root_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Dashboard")
    end
  end
end
