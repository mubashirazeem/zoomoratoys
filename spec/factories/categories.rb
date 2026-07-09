FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "#{Faker::Commerce.department(max: 1)} #{n}" }
    slug { name.parameterize }
    description { Faker::Lorem.paragraph }
    position { 0 }
    placeholder_key { Category::PLACEHOLDER_KEYS.sample }
  end
end
