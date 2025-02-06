class AddStatsMarketingAndTaxExemptFieldsToSpreeUsersTable < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_users, :completed_orders_count, :integer, null: false, default: 0, if_not_exists: true
    add_column :spree_users, :amount_spent, :decimal, null: false, default: 0, precision: 8, scale: 2, if_not_exists: true
    add_column :spree_users, :accepts_email_marketing, :boolean, default: false, null: false, if_not_exists: true
    add_column :spree_users, :accepts_sms_marketing, :boolean, default: false, null: false, if_not_exists: true
    add_column :spree_users, :tax_exempt, :boolean, default: false, null: false, if_not_exists: true

    add_index :spree_users, :completed_orders_count, if_not_exists: true
    add_index :spree_users, :amount_spent, if_not_exists: true
    add_index :spree_users, :accepts_email_marketing, if_not_exists: true
    add_index :spree_users, :accepts_sms_marketing, if_not_exists: true
    add_index :spree_users, :tax_exempt, if_not_exists: true
  end
end
