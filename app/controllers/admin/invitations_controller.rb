# frozen_string_literal: true

# Overrides devise_invitable's own controller for #new/#create only —
# sending an invite must never be reachable by anyone but a signed-in
# Owner. Admin::AdminUsersController is the real, hand-built UI for that,
# but the gem still routes these two by default, so they get locked down
# here too rather than trusted to just go unused.
#
# #edit/#update (accepting an invite, setting a password) and #destroy
# (declining one) are deliberately left exactly as Devise provides them —
# all three are self-service actions for someone who isn't an admin yet,
# by definition (the gem's own controller already prepends
# require_no_authentication on them, and scopes #destroy by the secret
# invitation_token from the email, not by id) — adding authentication here
# would conflict with require_no_authentication and break the real,
# legitimate use of those actions rather than add any real protection.
class Admin::InvitationsController < Devise::InvitationsController
  before_action :authenticate_admin_user!, only: [ :new, :create ]
  before_action :require_owner!, only: [ :new, :create ]

  layout "admin"

  private

  def require_owner!
    return if current_admin_user.owner?

    redirect_to admin_root_path, alert: "That page is only available to owners."
  end
end
