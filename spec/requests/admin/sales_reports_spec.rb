require "rails_helper"

RSpec.describe "Admin::SalesReports", type: :request do
  describe "GET /admin/sales-reports" do
    it "redirects an anonymous visitor to admin sign in" do
      get admin_sales_reports_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "as a signed-in admin" do
    before { sign_in create(:admin_user), scope: :admin_user }

    it "totals revenue only from processing, shipped, or delivered orders" do
      create(:order, status: "delivered", total_cents: 100_00)
      create(:order, status: "processing", total_cents: 50_00)
      create(:order, status: "pending", total_cents: 999_00)
      create(:order, status: "cancelled", total_cents: 999_00)

      get admin_sales_reports_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("AED 150")
    end

    it "keeps two differently-priced products with the same name as separate rows" do
      category = create(:category)
      product_a = create(:product, name: "Kids Bike", slug: "kids-bike-red", category: category, price_cents: 100_00)
      product_b = create(:product, name: "Kids Bike", slug: "kids-bike-blue", category: category, price_cents: 200_00)
      order = create(:order)
      create(:line_item, order: order, product: product_a, quantity: 3)
      create(:line_item, order: order, product: product_b, quantity: 5)

      get admin_sales_reports_path

      expect(response.body).to include(">3<")
      expect(response.body).to include(">5<")
    end
  end
end
