require "rails_helper"

RSpec.describe User, type: :model do
  it "has a valid factory" do
    expect(build(:user)).to be_valid
  end

  it { is_expected.to have_many(:orders).dependent(:destroy) }
  it { is_expected.to have_many(:reviews).dependent(:destroy) }

  it "requires a first and last name" do
    user = build(:user, first_name: "", last_name: "")

    expect(user).not_to be_valid
    expect(user.errors[:first_name]).to be_present
    expect(user.errors[:last_name]).to be_present
  end

  it "requires a unique, case-insensitive email (Devise's :validatable)" do
    create(:user, email: "family@example.com")
    duplicate = build(:user, email: "FAMILY@example.com")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to be_present
  end

  describe "#full_name" do
    it "joins first and last name" do
      user = build(:user, first_name: "Jamie", last_name: "Rider")

      expect(user.full_name).to eq("Jamie Rider")
    end
  end
end
