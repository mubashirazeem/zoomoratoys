require "rails_helper"

RSpec.describe "Addresses", type: :request do
  describe "GET /account/addresses" do
    it "requires sign-in" do
      get addresses_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows only the current user's own addresses" do
      user = create(:user)
      mine = create(:address, user: user, label: "Home")
      other = create(:address, label: "Someone Else's")
      sign_in user

      get addresses_path

      expect(response.body).to include("Home")
      expect(response.body).not_to include("Someone Else's")
    end
  end

  describe "POST /account/addresses" do
    it "creates a real address for the current user" do
      user = create(:user)
      sign_in user

      expect {
        post addresses_path, params: { address: {
          full_name: "Layla Ahmed", phone: "+971501234567",
          address_line1: "Villa 12", city: "Dubai", emirate: "Dubai"
        } }
      }.to change(user.addresses, :count).by(1)
    end

    it "makes the first address default automatically" do
      user = create(:user)
      sign_in user

      post addresses_path, params: { address: {
        full_name: "Layla Ahmed", phone: "+971501234567",
        address_line1: "Villa 12", city: "Dubai", emirate: "Dubai"
      } }

      expect(user.addresses.sole.default_address).to be true
    end
  end

  describe "DELETE /account/addresses/:id" do
    it "only deletes the current user's own address" do
      other_users_address = create(:address)
      sign_in create(:user)

      delete address_path(other_users_address)

      expect(response).to have_http_status(:not_found)
      expect(Address.exists?(other_users_address.id)).to be true
    end
  end
end
