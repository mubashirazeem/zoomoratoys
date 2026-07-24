# frozen_string_literal: true

# "Let customers speak for us" social-proof section — real Review data
# only. Featured reviews are the highest-rated ones (standard "put your
# best reviews forward" marketing practice), never fabricated ones. Hides
# itself entirely rather than show a hollow "0 reviews" state before the
# store has any (see #render?).
class Marketing::ReviewsComponent < ViewComponent::Base
  FEATURED_COUNT = 3

  def render?
    review_count.positive?
  end

  def reviews
    @reviews ||= Review.includes(:user).order(rating: :desc, created_at: :desc).limit(FEATURED_COUNT)
  end

  def average_rating
    @average_rating ||= Review.average(:rating)&.round(1)
  end

  def review_count
    @review_count ||= Review.count
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
