FactoryBot.define do
  factory :order do
    user
    sequence(:order_number) { |n| "ZMR-TEST-#{n}" }
    status { "pending" }
    total_cents { 0 }
    subtotal_cents { 0 }
    gift_wrap_cents { 0 }
    placed_at { Time.current }
    shipping_name { "Layla Ahmed" }
    shipping_phone { "+971501234567" }
    shipping_address_line1 { "Villa 12, Al Wasl Road" }
    shipping_city { "Dubai" }
    shipping_emirate { "Dubai" }
    payment_method { "pay_on_delivery" }
  end
end
