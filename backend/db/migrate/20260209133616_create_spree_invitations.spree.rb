# This migration comes from spree (originally 20250410061306)
class CreateSpreeInvitations < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_invitations do |t|
      t.string :email, index: true, null: false
      t.string :token, index: { unique: true }, null: false
      t.string :status, null: false, index: true

      t.references :resource, polymorphic: true, index: true, null: false # eg. Store, Vendor, Account
      t.references :inviter, polymorphic: true, index: true, null: false
      t.references :invitee, polymorphic: true, index: true
      t.references :role, null: false

      t.datetime :accepted_at
      t.datetime :expires_at, index: true
      t.datetime :deleted_at, index: true

      t.timestamps
    end
  end
end
