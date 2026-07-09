FactoryBot.define do
  factory :product do
    category
    sequence(:name) { |n| "#{Faker::Vehicle.make} #{n}" }
    slug { name.parameterize }
    description { Faker::Lorem.paragraph }
    price_cents { Faker::Number.between(from: 5_000, to: 500_000) }
    sequence(:sku) { |n| "ZMR-#{n.to_s.rjust(5, '0')}" }
    stock_status { "in_stock" }
    featured { false }
    best_seller { false }
    position { 0 }
    placeholder_key { Category::PLACEHOLDER_KEYS.sample }

    trait :featured do
      featured { true }
    end

    trait :best_seller do
      best_seller { true }
    end

    trait :sold_out do
      stock_status { "sold_out" }
    end
  end
end
