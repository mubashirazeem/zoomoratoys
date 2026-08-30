require "rails_helper"

RSpec.describe "Admin::AdminUsers", type: :request do
  describe "GET /admin/admin_users" do
    it "redirects an anonymous visitor to admin sign in" do
      get admin_admin_users_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  describe "as a signed-in owner" do
    before { @owner = create(:admin_user, name: "The Owner") }

    it "lists every admin user" do
      create(:admin_user, :staff, name: "Staff One")
      sign_in @owner, scope: :admin_user

      get admin_admin_users_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("The Owner")
      expect(response.body).to include("Staff One")
    end

    it "invites a new admin by email, defaulting to staff" do
      sign_in @owner, scope: :admin_user

      expect {
        post admin_admin_users_path, params: { admin_user: { name: "New Hire", email: "new.hire@example.com", role: "staff" } }
      }.to change(AdminUser, :count).by(1).and change { ActionMailer::Base.deliveries.count }.by(1)

      invited = AdminUser.find_by(email: "new.hire@example.com")
      expect(invited.role).to eq("staff")
      expect(invited.invited_by).to eq(@owner)
      expect(response).to redirect_to(admin_admin_users_path)
    end

    it "refuses to invite a second owner, even by posting role directly (the invite form only ever offers Staff)" do
      sign_in @owner, scope: :admin_user

      expect {
        post admin_admin_users_path, params: { admin_user: { name: "Co-Owner", email: "co.owner@example.com", role: "owner" } }
      }.not_to change(AdminUser, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects an invite with no name" do
      sign_in @owner, scope: :admin_user

      expect {
        post admin_admin_users_path, params: { admin_user: { name: "", email: "blank.name@example.com" } }
      }.not_to change(AdminUser, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refuses to promote a staff admin to owner, even by posting role directly (the edit form only ever offers Staff)" do
      staff = create(:admin_user, :staff)
      sign_in @owner, scope: :admin_user

      patch admin_admin_user_path(staff), params: { admin_user: { role: "owner", active: true } }

      expect(staff.reload.role).to eq("staff")
    end

    it "deactivates another admin, immediately blocking their sign-in" do
      staff = create(:admin_user, :staff, active: true)
      sign_in @owner, scope: :admin_user

      patch admin_admin_user_path(staff), params: { admin_user: { role: "staff", active: false } }

      staff.reload
      expect(staff.active?).to be false
      expect(staff.active_for_authentication?).to be false
    end

    it "refuses to let an owner change their own role or deactivate themselves — the one guard against locking everyone out" do
      sign_in @owner, scope: :admin_user

      patch admin_admin_user_path(@owner), params: { admin_user: { role: "staff", active: false } }

      expect(@owner.reload.role).to eq("owner")
      expect(@owner.reload.active?).to be true
      expect(flash[:alert]).to match(/can't change your own/i)
    end
  end

  describe "as a signed-in staff admin (not owner)" do
    it "is redirected away from the admin users list — this is the roster of who has access, staff shouldn't manage it" do
      sign_in create(:admin_user, :staff), scope: :admin_user

      get admin_admin_users_path

      expect(response).to redirect_to(admin_root_path)
    end

    it "cannot invite a new admin by posting directly to the endpoint either" do
      sign_in create(:admin_user, :staff), scope: :admin_user

      expect {
        post admin_admin_users_path, params: { admin_user: { name: "Sneaky", email: "sneaky@example.com", role: "owner" } }
      }.not_to change(AdminUser, :count)
    end
  end
end
