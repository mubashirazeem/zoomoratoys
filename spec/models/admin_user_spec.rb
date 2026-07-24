require "rails_helper"

RSpec.describe AdminUser, type: :model do
  it "has a valid factory" do
    expect(build(:admin_user)).to be_valid
  end

  it "requires a name" do
    admin_user = build(:admin_user, name: "")

    expect(admin_user).not_to be_valid
    expect(admin_user.errors[:name]).to be_present
  end

  it "requires a unique, case-insensitive email (Devise's :validatable)" do
    create(:admin_user, email: "owner@example.com")
    duplicate = build(:admin_user, email: "OWNER@example.com")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to be_present
  end

  it "locks after too many failed sign-in attempts (:lockable)" do
    admin_user = create(:admin_user)

    11.times { admin_user.valid_for_authentication? { false } }

    expect(admin_user.reload.access_locked?).to be true
  end
end
