require "rails_helper"

RSpec.describe "Orders", type: :request do
  describe "GET /account/orders" do
    it "redirects an anonymous visitor to sign in" do
      get account_orders_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows an empty state for a signed-in user with no orders" do
      sign_in create(:user)

      get account_orders_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("You haven't placed any orders yet")
    end

    it "shows only the current user's orders, newest first" do
      user = create(:user)
      other_user = create(:user)
      older = create(:order, user: user, order_number: "ZT-000001", placed_at: 2.days.ago)
      newer = create(:order, user: user, order_number: "ZT-000002", placed_at: 1.hour.ago)
      create(:order, user: other_user, order_number: "ZT-000003")
      sign_in user

      get account_orders_path

      expect(response.body).to include("ZT-000001")
      expect(response.body).to include("ZT-000002")
      expect(response.body).not_to include("ZT-000003")
      expect(response.body.index(newer.order_number)).to be < response.body.index(older.order_number)
    end
  end
end
