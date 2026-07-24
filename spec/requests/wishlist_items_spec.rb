require "rails_helper"

RSpec.describe "WishlistItems", type: :request do
  describe "POST /wishlist_items/:product_id/toggle" do
    it "requires sign-in" do
      product = create(:product)

      post toggle_wishlist_item_path(product)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "adds the product when it isn't already wishlisted" do
      user = create(:user)
      product = create(:product)
      sign_in user

      expect { post toggle_wishlist_item_path(product) }.to change(WishlistItem, :count).by(1)
      expect(user.wishlist_items.sole.product).to eq(product)
    end

    it "removes the product when it's already wishlisted" do
      user = create(:user)
      product = create(:product)
      create(:wishlist_item, user: user, product: product)
      sign_in user

      expect { post toggle_wishlist_item_path(product) }.to change(WishlistItem, :count).by(-1)
    end
  end
end
