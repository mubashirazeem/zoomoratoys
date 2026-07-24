class AddStripeFieldsToCoupons < ActiveRecord::Migration[7.2]
  def change
    add_column :coupons, :stripe_coupon_id, :string
    add_column :coupons, :stripe_promotion_code_id, :string
  end
end
