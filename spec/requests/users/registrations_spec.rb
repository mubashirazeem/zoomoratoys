require "rails_helper"

RSpec.describe "User registration", type: :request do
  describe "POST /users" do
    it "creates an account and signs the user in" do
      post user_registration_path, params: {
        user: {
          first_name: "Jamie", last_name: "Rider", email: "jamie@example.com",
          password: "password123", password_confirmation: "password123"
        }
      }

      expect(User.find_by(email: "jamie@example.com")).to be_present
      expect(response).to redirect_to(root_path)
    end

    it "creates a newsletter subscriber when the marketing checkbox is checked" do
      expect {
        post user_registration_path, params: {
          user: {
            first_name: "Jamie", last_name: "Rider", email: "subscriber@example.com",
            password: "password123", password_confirmation: "password123",
            subscribe_to_newsletter: "1"
          }
        }
      }.to change(NewsletterSubscriber, :count).by(1)

      expect(NewsletterSubscriber.last.email).to eq("subscriber@example.com")
    end

    it "does not create a newsletter subscriber when the checkbox is unchecked" do
      expect {
        post user_registration_path, params: {
          user: {
            first_name: "Jamie", last_name: "Rider", email: "no-thanks@example.com",
            password: "password123", password_confirmation: "password123"
          }
        }
      }.not_to change(NewsletterSubscriber, :count)
    end

    it "rejects a sign-up missing a required field" do
      expect {
        post user_registration_path, params: {
          user: { first_name: "", last_name: "Rider", email: "incomplete@example.com",
                   password: "password123", password_confirmation: "password123" }
        }
      }.not_to change(User, :count)
    end
  end

  describe "sign in / sign out" do
    it "signs an existing user in and back out" do
      user = create(:user, email: "returning@example.com", password: "password123")

      post user_session_path, params: { user: { email: user.email, password: "password123" } }
      expect(response).to redirect_to(root_path)

      delete destroy_user_session_path
      expect(response).to have_http_status(:see_other).or have_http_status(:found)
    end
  end
end
