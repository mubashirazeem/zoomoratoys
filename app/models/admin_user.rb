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
  has_paper_trail ignore: [
    :encrypted_password, :reset_password_token, :reset_password_sent_at,
    :remember_created_at, :sign_in_count, :current_sign_in_at, :last_sign_in_at,
    :current_sign_in_ip, :last_sign_in_ip, :failed_attempts, :unlock_token, :locked_at
  ]

  devise :database_authenticatable, :recoverable, :rememberable,
         :validatable, :trackable, :lockable, :timeoutable

  validates :name, presence: true
end
