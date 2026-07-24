FactoryBot.define do
  factory :product_variant do
    product
    sequence(:sku) { |n| "ZMR-VAR-#{n.to_s.rjust(5, '0')}" }
    options { { "Color" => "Racing Red", "Size" => "Standard" } }
    stock_quantity { 10 }
  end
end
