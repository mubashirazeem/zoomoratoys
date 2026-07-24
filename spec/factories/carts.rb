FactoryBot.define do
  factory :cart do
    user

    trait :guest do
      user { nil }
      sequence(:guest_token) { |n| "guest-token-#{n}" }
    end
  end
end
