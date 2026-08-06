# frozen_string_literal: true

require "rails_helper"

RSpec.describe Marketing::ReviewsComponent, type: :component do
  it "does not render when there are no reviews yet" do
    render_inline(described_class.new(reviews: Review.none, average_rating: nil, review_count: 0))

    expect(page).to have_no_css("section")
  end

  it "shows the real average rating, review count, and featured reviews" do
    product = create(:product)
    reviewer = create(:user, first_name: "Layla", last_name: "Ahmed")
    review = create(:review, product: product, user: reviewer, rating: 5, comment: "Fantastic scooter for the kids.")
    create(:review, product: create(:product), user: create(:user), rating: 3, comment: "Decent but delivery was slow.")

    render_inline(described_class.new(reviews: Review.includes(:user).where(id: review.id), average_rating: 4.0, review_count: 2))

    expect(page).to have_text("4.0") # average of 5 and 3
    expect(page).to have_text("2") # review_count
    expect(page).to have_text("Fantastic scooter for the kids.")
    expect(page).to have_text("Layla A.")
    expect(page).to have_no_text("Ahmed") # only first name + last initial, not full legal name
  end

  it "hides again once every review is deleted" do
    product = create(:product)
    review = create(:review, product: product)

    render_inline(described_class.new(reviews: Review.where(id: review.id), average_rating: review.rating.to_f, review_count: 1))
    expect(page).to have_css("section")

    review.destroy!

    render_inline(described_class.new(reviews: Review.none, average_rating: nil, review_count: 0))
    expect(page).to have_no_css("section")
  end
end
