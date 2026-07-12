FactoryBot.define do
  factory :review do
    user
    product
    rating { 5 }
    comment { "Great product, exactly as described." }
  end
end
