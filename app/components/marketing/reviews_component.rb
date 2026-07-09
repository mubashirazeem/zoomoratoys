# frozen_string_literal: true

# "Let customers speak for us" social-proof section: aggregate rating plus a
# row of review cards. All review copy, names, and ratings are original
# placeholder content for this frontend pass.
class Marketing::ReviewsComponent < ViewComponent::Base
  Review = Struct.new(:quote, :author, :stars, :image, keyword_init: true)

  AVERAGE_RATING = 4.8
  REVIEW_COUNT = 1_240

  REVIEWS = [
    Review.new(
      quote: "Delivery was quick and the team assembled everything in minutes. My kids were riding within the hour.",
      author: "Layla A.", stars: 5, image: "category-rideon.jpg"
    ),
    Review.new(
      quote: "Solid build quality and it handles the rough ground at the park really well. Worth every dirham.",
      author: "Omar R.", stars: 5, image: "category-scooter.jpg"
    ),
    Review.new(
      quote: "Ordered for a birthday and it arrived a day early, beautifully packed. The whole family loves it.",
      author: "Sara M.", stars: 5, image: "category-bicycle.jpg"
    )
  ].freeze

  def reviews
    REVIEWS
  end

  def average_rating
    AVERAGE_RATING
  end

  def review_count
    REVIEW_COUNT
  end

  # Hand-rolled thousands delimiter — ActionView number helpers aren't
  # reliably mixed into ViewComponent (matches Ui::PriceComponent's approach).
  def formatted_review_count
    REVIEW_COUNT.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end
end
