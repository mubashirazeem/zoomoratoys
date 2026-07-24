class AddStripeFieldsToOrders < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :orders, :stripe_checkout_session_id, :string
    add_column :orders, :stripe_payment_intent_id, :string
    add_column :orders, :stripe_invoice_id, :string
    add_column :orders, :refunded_cents, :integer, null: false, default: 0
    add_index :orders, :stripe_checkout_session_id, unique: true, algorithm: :concurrently
  end
end
