FactoryBot.define do
  factory :coupon do
    sequence(:code) { |n| "SAVE#{n}" }
    discount_type { "percentage" }
    discount_value { 20 }
    active { true }

    trait :fixed_amount do
      discount_type { "fixed_amount" }
      discount_value { 50 }
    end

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :usage_limit_reached do
      usage_limit { 5 }
      times_used { 5 }
    end
  end
end
