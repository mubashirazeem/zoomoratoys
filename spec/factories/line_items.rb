FactoryBot.define do
  factory :line_item do
    order
    product
    quantity { 1 }
    price_cents { 10_000 }
  end
end
