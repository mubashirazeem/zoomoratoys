require "rails_helper"

RSpec.describe "Admin::Dashboard", type: :request do
  describe "GET /admin" do
    it "redirects an anonymous visitor to admin sign in" do
      get admin_root_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end

    it "shows the Coupons stat card to an owner" do
      sign_in create(:admin_user), scope: :admin_user

      get admin_root_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(admin_coupons_path)
    end

    it "does not show the Coupons stat card (or link) to staff — it's an owner-only page, so nothing on the dashboard should point at it" do
      sign_in create(:admin_user, :staff), scope: :admin_user

      get admin_root_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include(admin_coupons_path)
    end
  end
end
