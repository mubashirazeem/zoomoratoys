require "rails_helper"

RSpec.describe "Reviews", type: :request do
  describe "POST /shop/:product_slug/reviews" do
    it "redirects an anonymous visitor to sign in" do
      product = create(:product)

      post product_reviews_path(product), params: { review: { rating: 5, comment: "Great!" } }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "creates a review for a signed-in user and redirects back to the product" do
      product = create(:product)
      sign_in create(:user)

      expect {
        post product_reviews_path(product), params: { review: { rating: 4, comment: "Solid build quality." } }
      }.to change(Review, :count).by(1)

      expect(response).to redirect_to(product_path(product))
      follow_redirect!
      expect(response.body).to include("Solid build quality.")
    end

    it "rejects a review with no comment and shows the error" do
      product = create(:product)
      sign_in create(:user)

      expect {
        post product_reviews_path(product), params: { review: { rating: 5, comment: "" } }
      }.not_to change(Review, :count)

      expect(response).to redirect_to(product_path(product))
      follow_redirect!
      expect(response.body).to include("can&#39;t be blank")
    end

    it "rejects a second review from the same user for the same product" do
      product = create(:product)
      user = create(:user)
      create(:review, user: user, product: product)
      sign_in user

      expect {
        post product_reviews_path(product), params: { review: { rating: 3, comment: "Trying again." } }
      }.not_to change(Review, :count)

      expect(response).to redirect_to(product_path(product))
    end
  end

  describe "GET /shop/:slug with reviews" do
    it "shows the average rating and existing reviews" do
      product = create(:product)
      create(:review, product: product, rating: 5, comment: "Fantastic scooter for the price.")

      get product_path(product)

      expect(response.body).to include("Fantastic scooter for the price.")
      expect(response.body).to include("5.0")
    end

    it "shows an empty state when there are no reviews yet" do
      product = create(:product)

      get product_path(product)

      expect(response.body).to include("Be the first to review this product")
    end
  end
end
