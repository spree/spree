# Lets a staff account be switched off without deleting it, so records that
# name it as their actor keep their history. See Spree::AccountDeactivation.
class AddDeactivatedAtToSpreeAdminUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_admin_users, :deactivated_at, :datetime
  end
end
