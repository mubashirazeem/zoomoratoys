require "rails_helper"

RSpec.describe "CartItems", type: :request do
  describe "POST /cart_items" do
    it "adds a product to a guest cart, persisted across requests via a cookie" do
      product = create(:product)

      expect { post cart_items_path, params: { product_id: product.slug } }.to change(Cart, :count).by(1)
      expect(response).to redirect_to(cart_path)

      cart = Cart.last
      expect(cart.cart_items.sole.product).to eq(product)
    end

    it "increments quantity instead of duplicating the line when added twice" do
      product = create(:product)
      post cart_items_path, params: { product_id: product.slug, quantity: 1 }

      expect { post cart_items_path, params: { product_id: product.slug, quantity: 2 } }
        .not_to change(CartItem, :count)

      expect(Cart.last.cart_items.sole.quantity).to eq(3)
    end

    it "rejects adding a variant-having product with no variant chosen" do
      product = create(:product)
      create(:product_variant, product: product)

      post cart_items_path, params: { product_id: product.slug }

      expect(CartItem.count).to eq(0)
      expect(response).to redirect_to(product_path(product))
    end

    it "adds the exact chosen variant" do
      product = create(:product)
      variant = create(:product_variant, product: product, options: { "Color" => "Racing Red" })
      create(:product_variant, product: product, options: { "Color" => "Midnight Black" })

      post cart_items_path, params: { product_id: product.slug, product_variant_id: variant.id }

      expect(CartItem.sole.product_variant).to eq(variant)
    end

    it "refuses to add an out-of-stock product, with a clear error, and adds nothing" do
      product = create(:product, stock_quantity: 0, stock_status: "sold_out")

      post cart_items_path, params: { product_id: product.slug }

      expect(CartItem.count).to eq(0)
      expect(response).to redirect_to(product_path(product))
      follow_redirect!
      expect(response.body).to include("available")
    end

    it "refuses to add more than what's actually in stock" do
      product = create(:product, stock_quantity: 3)

      post cart_items_path, params: { product_id: product.slug, quantity: 5 }

      expect(CartItem.count).to eq(0)
      expect(response).to redirect_to(product_path(product))
    end

    it "refuses to add more of something already in the cart past what's available" do
      product = create(:product, stock_quantity: 3)
      post cart_items_path, params: { product_id: product.slug, quantity: 2 }

      post cart_items_path, params: { product_id: product.slug, quantity: 2 }

      expect(CartItem.sole.quantity).to eq(2)
    end

    it "redirects straight to checkout when buy_now is set" do
      product = create(:product)

      post cart_items_path, params: { product_id: product.slug, buy_now: "1" }

      expect(response).to redirect_to(checkout_path)
    end

    it "folds a guest cart into the user's cart on sign-in" do
      product = create(:product)
      post cart_items_path, params: { product_id: product.slug }
      guest_cart_id = Cart.last.id

      user = create(:user)
      sign_in user
      get cart_path # any request runs the merge-on-sign-in before_action

      expect(Cart.exists?(guest_cart_id)).to be false
      expect(user.reload.cart.cart_items.sole.product).to eq(product)
    end
  end

  describe "PATCH /cart_items/:id" do
    it "updates the quantity" do
      product = create(:product)
      post cart_items_path, params: { product_id: product.slug }
      item = CartItem.sole

      patch cart_item_path(item), params: { quantity: 5 }

      expect(item.reload.quantity).to eq(5)
    end

    it "removes the item when the quantity drops to zero" do
      product = create(:product)
      post cart_items_path, params: { product_id: product.slug }
      item = CartItem.sole

      patch cart_item_path(item), params: { quantity: 0 }

      expect(CartItem.exists?(item.id)).to be false
    end

    it "refuses to raise the quantity past what's actually in stock" do
      product = create(:product, stock_quantity: 3)
      post cart_items_path, params: { product_id: product.slug, quantity: 2 }
      item = CartItem.sole

      patch cart_item_path(item), params: { quantity: 10 }

      expect(item.reload.quantity).to eq(2)
      expect(response).to redirect_to(cart_path)
    end
  end

  describe "DELETE /cart_items/:id" do
    it "removes the item" do
      product = create(:product)
      post cart_items_path, params: { product_id: product.slug }
      item = CartItem.sole

      delete cart_item_path(item)

      expect(CartItem.exists?(item.id)).to be false
    end

    it "404s for a cart item that isn't the current visitor's" do
      other_cart = create(:cart, :guest)
      other_item = create(:cart_item, cart: other_cart)

      delete cart_item_path(other_item)

      expect(response).to have_http_status(:not_found)
    end
  end
end
