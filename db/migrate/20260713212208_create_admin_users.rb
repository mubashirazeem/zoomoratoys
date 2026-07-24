# frozen_string_literal: true

# Entirely separate table/Devise scope from the customer `users` table —
# see ARCHITECTURE.md for why (auth isolation: a bug in customer session
# handling can't touch admin capability, and vice versa). Includes
# :lockable, deliberately NOT enabled on the customer User model — a
# high-privilege account that can manage every order/customer/product
# warrants brute-force lockout protection even though customer accounts
# don't need it yet.
class CreateAdminUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :admin_users do |t|
      ## Database authenticatable
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Lockable
      t.integer  :failed_attempts, default: 0, null: false
      t.string   :unlock_token
      t.datetime :locked_at

      t.string :name, null: false

      t.timestamps null: false
    end

    add_index :admin_users, :email, unique: true
    add_index :admin_users, :reset_password_token, unique: true
    add_index :admin_users, :unlock_token, unique: true
  end
end
