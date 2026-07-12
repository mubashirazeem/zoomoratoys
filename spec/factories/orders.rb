FactoryBot.define do
  factory :order do
    user
    sequence(:order_number) { |n| "ZT-#{n.to_s.rjust(6, '0')}" }
    status { "pending" }
    total_cents { 0 }
    placed_at { Time.current }
  end
end
