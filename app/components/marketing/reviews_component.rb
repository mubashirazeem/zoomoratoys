# frozen_string_literal: true

# "Let customers speak for us" social-proof section — real Review data
# only. Featured reviews are the highest-rated ones (standard "put your
# best reviews forward" marketing practice), never fabricated ones. Hides
# itself entirely rather than show a hollow "0 reviews" state before the
# store has any (see #render?).
class Marketing::ReviewsComponent < ViewComponent::Base
  FEATURED_COUNT = 3

  def initialize(reviews: Review.none, average_rating: nil, review_count: 0)
    @reviews = reviews
    @average_rating = average_rating
    @review_count = review_count
  end

  attr_reader :reviews, :average_rating, :review_count

  def render?
    review_count.positive?
  end

  def formatted_review_count
    helpers.number_with_delimiter(review_count)
  end

  # First name + last initial — a real customer's name on a public
  # homepage, without publishing their full legal name.
  def reviewer_label(review)
    last_initial = review.user.last_name.first
    [ review.user.first_name, last_initial && "#{last_initial}." ].compact.join(" ")
  end

  def reviewer_initials(review)
    "#{review.user.first_name.first}#{review.user.last_name.first}".upcase
  end
end
