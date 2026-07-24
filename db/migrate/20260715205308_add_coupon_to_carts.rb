class AddCouponToCarts < ActiveRecord::Migration[7.2]
  def change
    add_reference :carts, :coupon, foreign_key: true
  end
end
