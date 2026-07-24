require "rails_helper"

RSpec.describe "Admin::Customers", type: :request do
  describe "GET /admin/customers" do
    it "redirects an anonymous visitor to admin sign in" do
      get admin_customers_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "as a signed-in admin" do
    before { sign_in create(:admin_user), scope: :admin_user }

    it "searches customers by name or email" do
      matching = create(:user, first_name: "Layla", last_name: "Ahmed", email: "layla@example.com")
      other = create(:user, first_name: "Omar", last_name: "Khan", email: "omar@example.com")

      get admin_customers_path(q: "layla")

      expect(response.body).to include(matching.full_name)
      expect(response.body).not_to include(other.full_name)
    end
  end

  describe "GET /admin/customers/:id" do
    before { sign_in create(:admin_user), scope: :admin_user }

    it "renders the customer's order history without crashing when it includes the system-managed statuses" do
      customer = create(:user)
      create(:order, user: customer, status: "awaiting_payment", order_number: "ZT-AP1")
      create(:order, user: customer, status: "refunded", order_number: "ZT-RF1")

      get admin_customer_path(customer)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Awaiting payment")
      expect(response.body).to include("Refunded")
    end
  end
end
