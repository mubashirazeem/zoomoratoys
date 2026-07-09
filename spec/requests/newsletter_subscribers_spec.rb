require "rails_helper"

RSpec.describe "NewsletterSubscribers", type: :request do
  describe "POST /newsletter" do
    it "creates a subscriber and redirects with a confirmation" do
      expect {
        post newsletter_subscribers_path, params: { newsletter_subscriber: { email: "shopper@example.com" } }, headers: { "HTTP_REFERER" => root_path }
      }.to change(NewsletterSubscriber, :count).by(1)

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Thanks for subscribing")
    end

    it "tells an already-subscribed email it's already on the list, without erroring" do
      create(:newsletter_subscriber, email: "shopper@example.com")

      expect {
        post newsletter_subscribers_path, params: { newsletter_subscriber: { email: "shopper@example.com" } }, headers: { "HTTP_REFERER" => root_path }
      }.not_to change(NewsletterSubscriber, :count)

      follow_redirect!
      expect(response.body).to include("already on the list")
    end

    it "redirects with an error for an invalid email" do
      post newsletter_subscribers_path, params: { newsletter_subscriber: { email: "not-an-email" } }, headers: { "HTTP_REFERER" => root_path }

      follow_redirect!
      expect(response.body).to include("Email is invalid")
    end
  end
end
