class CreateSpreeInvitations < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_invitations do |t|
      t.string :email, index: true, null: false
      t.string :token, index: { unique: true }, null: false
      t.string :status, null: false

      t.references :resource, polymorphic: true, index: true, null: false # eg. Store, Vendor, Account
      t.references :inviter, polymorphic: true, index: true, null: false
      t.references :invitee, polymorphic: true, index: true

      t.datetime :accepted_at
      t.datetime :revoked_at
      t.datetime :expires_at

      t.timestamps
    end

    # attach roles to invitations
    create_table :spree_invitation_roles do |t|
      t.references :invitation, null: false
      t.references :role, null: false

      t.timestamps
    end
    add_index :spree_invitation_roles, [:invitation_id, :role_id], unique: true
  end
end
