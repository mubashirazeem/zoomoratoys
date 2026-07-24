class AddStripeDisputeStatusToOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :orders, :stripe_dispute_status, :string
  end
end
