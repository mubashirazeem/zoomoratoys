require "rails_helper"

RSpec.describe "Admin::Coupons", type: :request do
  describe "GET /admin/coupons" do
    it "redirects an anonymous visitor to admin sign in" do
      get admin_coupons_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "as a signed-in admin" do
    before { sign_in create(:admin_user), scope: :admin_user }

    it "creates a coupon" do
      # This example is about the local DB record, not the Stripe sync (the
      # dedicated examples below cover that) — stub it out so this stays a
      # plain, un-vcr'd request spec with no real network call.
      allow(Payments::CouponSync).to receive(:create)

      expect {
        post admin_coupons_path, params: { coupon: { code: "welcome10", discount_type: "percentage", discount_value: 10 } }
      }.to change(Coupon, :count).by(1)

      expect(Coupon.last.code).to eq("WELCOME10")
    end

    it "rejects an invalid coupon" do
      expect {
        post admin_coupons_path, params: { coupon: { code: "", discount_type: "percentage", discount_value: 10 } }
      }.not_to change(Coupon, :count)
    end

    it "rejects a code with a space before it ever reaches Stripe sync — no more 'created, but Stripe sync failed' surprise" do
      expect {
        post admin_coupons_path, params: { coupon: { code: "Test cop", discount_type: "percentage", discount_value: 10 } }
      }.not_to change(Coupon, :count)

      expect(response.body).to include("letters, numbers, hyphens, and underscores")
    end

    it "deletes a coupon" do
      coupon = create(:coupon)

      expect {
        delete admin_coupon_path(coupon)
      }.to change(Coupon, :count).by(-1)
    end

    it "syncs a newly created coupon to Stripe", vcr: { cassette_name: "admin/coupons/create_syncs_to_stripe" } do
      post admin_coupons_path, params: { coupon: { code: "NEWYEAR30", discount_type: "percentage", discount_value: 30 } }

      coupon = Coupon.last
      expect(coupon.stripe_coupon_id).to be_present
      expect(coupon.stripe_promotion_code_id).to be_present
    end

    it "still saves the coupon even if Stripe sync fails, with a clear warning" do
      allow(Stripe::Coupon).to receive(:create).and_raise(Stripe::APIConnectionError.new("simulated"))

      post admin_coupons_path, params: { coupon: { code: "OFFLINE10", discount_type: "percentage", discount_value: 10 } }

      coupon = Coupon.find_by(code: "OFFLINE10")
      expect(coupon).to be_present
      expect(coupon.stripe_coupon_id).to be_nil
      expect(flash[:alert]).to match(/Stripe sync failed/i)
    end
  end
end
