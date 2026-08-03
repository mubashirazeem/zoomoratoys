FactoryBot.define do
  factory :promotional_banner do
    sequence(:title) { |n| "Promotion #{n}" }
    description { "Every order ships and is set up for you, anywhere in the Emirates." }
    cta_label { "Shop All" }
    cta_url { "/shop" }
    sequence(:position)
    active { true }
  end
end
