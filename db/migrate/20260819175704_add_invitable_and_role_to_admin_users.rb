class AddInvitableAndRoleToAdminUsers < ActiveRecord::Migration[7.2]
  def up
    add_column :admin_users, :invitation_token, :string
    add_column :admin_users, :invitation_created_at, :datetime
    add_column :admin_users, :invitation_sent_at, :datetime
    add_column :admin_users, :invitation_accepted_at, :datetime
    add_column :admin_users, :invitation_limit, :integer
    add_column :admin_users, :invited_by_type, :string
    add_column :admin_users, :invited_by_id, :bigint
    add_column :admin_users, :invitations_count, :integer, default: 0

    add_index :admin_users, :invitation_token, unique: true
    add_index :admin_users, :invited_by_id
    # Speeds up the admin list's "who hasn't accepted yet" grouping.
    add_index :admin_users, :invitation_accepted_at

    # New default is intentionally the least-privileged role — every admin
    # created going forward (i.e. every invite) starts as staff unless the
    # inviting Owner explicitly picks Owner in the form.
    add_column :admin_users, :role, :string, default: "staff", null: false
    add_column :admin_users, :active, :boolean, default: true, null: false

    # Every admin account that already exists today already has full,
    # unrestricted access — this preserves that instead of silently
    # demoting whoever's currently signed in to Staff on deploy.
    execute "UPDATE admin_users SET role = 'owner'"
  end

  def down
    remove_column :admin_users, :active
    remove_column :admin_users, :role
    remove_index :admin_users, :invitation_accepted_at
    remove_index :admin_users, :invited_by_id
    remove_index :admin_users, :invitation_token
    remove_column :admin_users, :invitations_count
    remove_column :admin_users, :invited_by_id
    remove_column :admin_users, :invited_by_type
    remove_column :admin_users, :invitation_limit
    remove_column :admin_users, :invitation_accepted_at
    remove_column :admin_users, :invitation_sent_at
    remove_column :admin_users, :invitation_created_at
    remove_column :admin_users, :invitation_token
  end
end
