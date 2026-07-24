class AddStripeHostedInvoiceUrlToOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :orders, :stripe_hosted_invoice_url, :string
  end
end
