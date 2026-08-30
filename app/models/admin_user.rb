# frozen_string_literal: true

# Entirely separate from the customer User model — its own table, own
# Devise scope, own session. Includes :lockable (brute-force protection),
# deliberately not enabled on User. See ARCHITECTURE.md for the auth
# isolation rationale.
class AdminUser < ApplicationRecord
  # Only name/email changes are worth an audit trail entry. Everything else
  # here is either a login-tracking secret (encrypted_password, the various
  # reset/unlock tokens) or churns on every single sign-in (:trackable's
  # sign_in_count/current_sign_in_at/etc.) and would just be noise, not a
  # meaningful "who changed what" record.
  # role/active are deliberately NOT ignored below — "who granted/changed
  # someone's admin access, and when" is exactly the kind of change this
  # audit trail exists to catch, unlike the login-tracking noise around it.
  has_paper_trail ignore: [
    :encrypted_password, :reset_password_token, :reset_password_sent_at,
    :remember_created_at, :sign_in_count, :current_sign_in_at, :last_sign_in_at,
    :current_sign_in_ip, :last_sign_in_ip, :failed_attempts, :unlock_token, :locked_at,
    :invitation_token, :invitation_created_at, :invitation_sent_at, :invitations_count
  ]

  devise :database_authenticatable, :recoverable, :rememberable,
         :validatable, :trackable, :lockable, :timeoutable, :invitable

  belongs_to :invited_by, class_name: "AdminUser", optional: true

  # staff is the default (see the AddInvitableAndRoleToAdminUsers migration)
  # — the least-privileged role is what a new admin_users row gets unless
  # something explicitly grants owner, same principle as a fresh Linux user
  # not landing in the sudoers file by accident.
  enum :role, { staff: "staff", owner: "owner" }, default: "staff", validate: true

  validates :name, presence: true
  # There is exactly one Owner, ever — not just a UI choice hidden from the
  # invite/edit dropdowns (see admin_users/new & edit views), but a real
  # invariant: nothing can save a second owner row, full stop.
  validate :only_one_owner, if: :owner?

  scope :active, -> { where(active: true) }

  # Devise's own hook for "credentials are correct but sign-in should still
  # be refused" — this is what actually enforces deactivation. Without this,
  # setting active: false would only hide someone from the admin list; they
  # could still sign in with their existing password.
  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :deactivated
  end

  private

  def only_one_owner
    return unless AdminUser.owner.where.not(id: id).exists?

    errors.add(:role, "already has one owner — only a single owner is allowed")
  end
end
