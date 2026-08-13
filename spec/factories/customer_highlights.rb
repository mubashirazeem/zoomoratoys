FactoryBot.define do
  factory :customer_highlight do
    sequence(:customer_name) { |n| "Customer #{n}" }
    quote { "Thank you for the awesome bike, it's really cool and the perfect size." }
    rating { 5 }
    sequence(:position)
    active { true }
  end
end
