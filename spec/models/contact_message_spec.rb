require "rails_helper"

RSpec.describe ContactMessage, type: :model do
  it "has a valid factory" do
    expect(build(:contact_message)).to be_valid
  end

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:subject) }
  it { is_expected.to validate_presence_of(:message) }

  describe "email validation" do
    it { is_expected.to validate_presence_of(:email) }

    it "accepts a well-formed email" do
      message = build(:contact_message, email: "shopper@example.com")

      expect(message).to be_valid
    end

    it "rejects a malformed email" do
      message = build(:contact_message, email: "not-an-email")

      expect(message).not_to be_valid
      expect(message.errors[:email]).to be_present
    end
  end
end
