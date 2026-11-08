# Written whenever a session starts or refreshes (see Spree::RefreshToken), so
# it outlives the sessions themselves, which signing out deletes.
class AddLastActiveAtToSpreeAdminUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_admin_users, :last_active_at, :datetime
  end
end
