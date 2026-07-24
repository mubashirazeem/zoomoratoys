FactoryBot.define do
  factory :blog_post do
    sequence(:title) { |n| "Family Adventure Tips #{n}" }
    slug { title.parameterize }
    excerpt { "A short teaser about this post." }
    body { "The full body of this blog post, with real advice for real families." }
    cover_image_key { Category::PLACEHOLDER_KEYS.sample }
    published_at { 1.day.ago }

    trait :draft do
      published_at { 1.day.from_now }
    end
  end
end
