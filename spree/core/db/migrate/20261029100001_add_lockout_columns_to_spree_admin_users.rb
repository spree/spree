# Spree::AccountLockout reads these columns. Installs upgraded from a Devise
# admin model without :lockable reach 6.0 with neither of them.
class AddLockoutColumnsToSpreeAdminUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_admin_users, :failed_attempts, :integer unless column_exists?(:spree_admin_users, :failed_attempts)
    add_column :spree_admin_users, :locked_at, :datetime unless column_exists?(:spree_admin_users, :locked_at)
  end
end
