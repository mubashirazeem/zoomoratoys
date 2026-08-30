require "rails_helper"

RSpec.describe "Admin::Orders", type: :request do
  describe "PATCH /admin/orders/:id (cancelling a Tamara order)" do
    before { sign_in create(:admin_user), scope: :admin_user }

    let(:order) { create(:order, payment_method: "tamara", status: "pending", tamara_order_id: "order_abc", total_cents: 10_000) }

    it "calls Tamara's Cancel Order API and updates the local status" do
      order
      expect(Payments::Tamara).to receive(:post).with("/orders/order_abc/cancel", anything).and_return({})

      patch admin_order_path(order), params: { order: { status: "cancelled" } }

      expect(order.reload.status).to eq("cancelled")
      expect(response).to redirect_to(admin_order_path(order))
    end

    it "does not change the local status if Tamara's cancel call fails — our records must not diverge from Tamara's" do
      order
      allow(Payments::Tamara).to receive(:post).and_raise(Payments::ProviderError, "Tamara API error (409) on /orders/order_abc/cancel: already captured")

      patch admin_order_path(order), params: { order: { status: "cancelled" } }

      expect(order.reload.status).to eq("pending")
      expect(flash[:alert]).to include("Couldn't cancel this order with Tamara")
    end

    it "does not call Tamara at all for a non-Tamara order" do
      pay_on_delivery_order = create(:order, payment_method: "pay_on_delivery", status: "pending")
      expect(Payments::Tamara).not_to receive(:post)

      patch admin_order_path(pay_on_delivery_order), params: { order: { status: "cancelled" } }

      expect(pay_on_delivery_order.reload.status).to eq("cancelled")
    end
  end

  describe "POST /admin/orders/:id/refund" do
    before { sign_in create(:admin_user), scope: :admin_user }

    it "refunds a captured Tabby order through Payments::Tabby::RefundIssuer, not the Stripe one" do
      order = create(:order, payment_method: "tabby", status: "processing", tabby_payment_id: "pay_123", total_cents: 10_000)
      expect(Payments::Tabby::RefundIssuer).to receive(:call).with(order: order).and_call_original
      allow(Payments::Tabby).to receive(:post).and_return({})

      post refund_admin_order_path(order)

      expect(response).to redirect_to(admin_order_path(order))
      expect(order.reload.status).to eq("refunded")
    end

    it "refuses to refund a Tabby order that's still awaiting_payment" do
      order = create(:order, payment_method: "tabby", status: "awaiting_payment", tabby_payment_id: "pay_123", total_cents: 10_000)
      expect(Payments::Tabby::RefundIssuer).not_to receive(:call)

      post refund_admin_order_path(order)

      expect(flash[:alert]).to eq("This order can't be refunded.")
    end

    it "shows a friendly error, without crashing, if Tabby's refund call fails" do
      order = create(:order, payment_method: "tabby", status: "processing", tabby_payment_id: "pay_123", total_cents: 10_000)
      allow(Payments::Tabby).to receive(:post).and_raise(Payments::ProviderError, "simulated")

      post refund_admin_order_path(order)

      expect(order.reload.status).to eq("processing")
      expect(flash[:alert]).to match(/Refund failed/)
    end
  end
end
