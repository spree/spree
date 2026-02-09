# This migration comes from spree (originally 20250207084000)
class AddAcceptsEmailMarketingFieldToSpreeUsersTable < ActiveRecord::Migration[6.1]
  def change
    add_column Spree.user_class.table_name, :accepts_email_marketing, :boolean, default: false, null: false, if_not_exists: true
    add_index Spree.user_class.table_name, :accepts_email_marketing, if_not_exists: true
  end
end
