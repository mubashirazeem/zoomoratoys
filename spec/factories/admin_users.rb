FactoryBot.define do
  factory :admin_user do
    sequence(:email) { |n| "admin#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    name { "Store Admin" }
    role { "owner" }

    trait :staff do
      role { "staff" }
    end
  end
end
