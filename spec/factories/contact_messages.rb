FactoryBot.define do
  factory :contact_message do
    name { Faker::Name.name }
    email { Faker::Internet.email }
    phone { Faker::PhoneNumber.phone_number }
    subject { Faker::Lorem.sentence(word_count: 4) }
    message { Faker::Lorem.paragraph }
  end
end
