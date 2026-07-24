FactoryBot.define do
  factory :address do
    user
    full_name { "Layla Ahmed" }
    phone { "+971501234567" }
    address_line1 { "Villa 12, Al Wasl Road" }
    city { "Dubai" }
    emirate { "Dubai" }
  end
end
