require "rails_helper"

RSpec.describe "Admin::Invitations", type: :request do
  # devise_invitable routes these three by default; Admin::AdminUsersController
  # is the real, intended way to send an invite, but these gem-provided
  # routes still exist and must not be a back door around require_owner!.
  describe "GET /admin_users/invitation/new" do
    it "redirects an anonymous visitor to sign in, not to the form" do
      get new_admin_user_invitation_path

      expect(response).to redirect_to(new_admin_user_session_path)
    end

    it "is refused to a signed-in staff admin" do
      sign_in create(:admin_user, :staff), scope: :admin_user

      get new_admin_user_invitation_path

      expect(response).to redirect_to(admin_root_path)
    end

    it "is allowed for a signed-in owner" do
      sign_in create(:admin_user), scope: :admin_user

      get new_admin_user_invitation_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /admin_users/invitation" do
    it "cannot be used by an anonymous visitor to invite themselves" do
      expect {
        post admin_user_invitation_path, params: { admin_user: { name: "Nobody", email: "nobody@example.com" } }
      }.not_to change(AdminUser, :count)

      expect(response).to redirect_to(new_admin_user_session_path)
    end

    it "cannot be used by a staff admin either" do
      sign_in create(:admin_user, :staff), scope: :admin_user

      expect {
        post admin_user_invitation_path, params: { admin_user: { name: "Sneaky", email: "sneaky@example.com" } }
      }.not_to change(AdminUser, :count)
    end
  end

  describe "GET /admin_users/invitation/remove (declining an invite)" do
    # Deliberately left as devise_invitable's own self-service action (see
    # Admin::InvitationsController's comment) — an unauthenticated visitor
    # IS meant to be able to hit this, but only with the real secret token
    # from their invitation email, not by guessing an id.
    it "requires the real invitation token — a missing/wrong one doesn't remove anything" do
      pending_admin = AdminUser.invite!({ name: "Pending", email: "pending@example.com" }, create(:admin_user))

      get remove_admin_user_invitation_path(invitation_token: "not-the-real-token")

      expect(AdminUser.exists?(pending_admin.id)).to be true
    end

    it "removes the invitation when given the real token, without needing to be signed in" do
      pending_admin = AdminUser.invite!({ name: "Pending", email: "pending@example.com" }, create(:admin_user))

      get remove_admin_user_invitation_path(invitation_token: pending_admin.raw_invitation_token)

      expect(AdminUser.exists?(pending_admin.id)).to be false
    end
  end

  describe "GET /admin_users/invitation/accept (accepting a real invite)" do
    it "is reachable by the invited person without being signed in — that's the whole point" do
      invited = AdminUser.invite!({ name: "New Hire", email: "new.hire@example.com" }, create(:admin_user))

      get accept_admin_user_invitation_path(invitation_token: invited.raw_invitation_token)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("New Hire")
    end

    it "lets the invited person set a password and finish setting up their account" do
      invited = AdminUser.invite!({ name: "New Hire", email: "new.hire@example.com", role: "staff" }, create(:admin_user))
      token = invited.raw_invitation_token

      put admin_user_invitation_path, params: {
        admin_user: { invitation_token: token, password: "brand-new-password123", password_confirmation: "brand-new-password123" }
      }

      invited.reload
      expect(invited.invitation_accepted_at).to be_present
      expect(invited.valid_password?("brand-new-password123")).to be true
    end
  end
end
