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

  describe "role" do
    it "defaults new records to the least-privileged role, staff" do
      admin_user = AdminUser.new
      expect(admin_user.role).to eq("staff")
    end

    it "allows only one owner to exist at a time" do
      create(:admin_user) # factory default is owner
      second_owner = build(:admin_user, role: "owner")

      expect(second_owner).not_to be_valid
      expect(second_owner.errors[:role]).to be_present
    end

    it "lets the existing owner keep saving as owner (the validation excludes itself)" do
      owner = create(:admin_user)
      owner.name = "Renamed"

      expect(owner.save).to be true
    end

    it "allows any number of staff accounts" do
      create(:admin_user) # the one owner
      create(:admin_user, :staff)
      third = build(:admin_user, :staff)

      expect(third).to be_valid
    end

    it "rejects a role outside owner/staff" do
      admin_user = build(:admin_user, role: "superadmin")

      expect(admin_user).not_to be_valid
      expect(admin_user.errors[:role]).to be_present
    end
  end

  describe "#active_for_authentication?" do
    it "allows sign-in for an active account" do
      admin_user = create(:admin_user, active: true)
      expect(admin_user.active_for_authentication?).to be true
    end

    it "blocks sign-in for a deactivated account, even with the correct password — this is what actually enforces deactivation, not just hiding them from the admin list" do
      admin_user = create(:admin_user, active: false)
      expect(admin_user.active_for_authentication?).to be false
    end

    it "gives a clear reason (not the generic Devise message) when a deactivated account tries to sign in" do
      admin_user = create(:admin_user, active: false)
      expect(admin_user.inactive_message).to eq(:deactivated)
    end
  end

  describe "#invited_to_sign_up? (devise_invitable)" do
    it "is true for a freshly invited admin who hasn't set a password yet — this is what the admin list shows as \"Invite pending\"" do
      admin_user = AdminUser.invite!({ name: "New Hire", email: "new.hire@example.com" }, create(:admin_user))
      expect(admin_user.invited_to_sign_up?).to be true
    end

    it "is false for a normal directly-created admin (no invitation involved) — must not show as permanently pending" do
      admin_user = create(:admin_user)
      expect(admin_user.invited_to_sign_up?).to be false
    end
  end

  describe ".invite!" do
    it "creates a real, findable admin user with no usable password yet, and records who invited them" do
      owner = create(:admin_user, name: "Existing Owner")

      expect {
        AdminUser.invite!({ name: "New Hire", email: "new.hire@example.com", role: "staff" }, owner)
      }.to change(AdminUser, :count).by(1)

      invited = AdminUser.find_by(email: "new.hire@example.com")
      expect(invited).to be_present
      expect(invited.invited_by).to eq(owner)
      expect(invited.invitation_token).to be_present
      expect(invited.role).to eq("staff")
    end

    it "sends the invitation email" do
      owner = create(:admin_user)

      expect {
        AdminUser.invite!({ name: "New Hire", email: "new.hire@example.com" }, owner)
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "new.hire@example.com" ])
    end

    it "does not create a second account for an email that's already accepted an invite" do
      create(:admin_user, :staff, email: "taken@example.com")
      owner = create(:admin_user)

      expect {
        invited = AdminUser.invite!({ name: "Someone Else", email: "taken@example.com" }, owner)
        expect(invited.errors[:email]).to be_present
      }.not_to change(AdminUser, :count)
    end
  end
end
