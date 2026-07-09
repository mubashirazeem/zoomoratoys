require "rails_helper"

RSpec.describe NewsletterSubscriber, type: :model do
  it "has a valid factory" do
    expect(build(:newsletter_subscriber)).to be_valid
  end

  it { is_expected.to validate_presence_of(:email) }

  it "rejects a malformed email" do
    subscriber = build(:newsletter_subscriber, email: "not-an-email")

    expect(subscriber).not_to be_valid
  end

  it "rejects a duplicate email" do
    create(:newsletter_subscriber, email: "shopper@example.com")
    duplicate = build(:newsletter_subscriber, email: "shopper@example.com")

    expect(duplicate).not_to be_valid
  end

  it "treats email as case-insensitively unique" do
    create(:newsletter_subscriber, email: "shopper@example.com")
    duplicate = build(:newsletter_subscriber, email: "Shopper@Example.com")

    expect(duplicate).not_to be_valid
  end

  it "normalizes email to lowercase and trimmed before saving" do
    subscriber = create(:newsletter_subscriber, email: "  Shopper@Example.com  ")

    expect(subscriber.email).to eq("shopper@example.com")
  end
end
