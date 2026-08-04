class AddAcceptsEmailMarketingFieldToSpreeUsersTable < ActiveRecord::Migration[6.1]
  def change
    return unless Spree.customer_class.present? && table_exists?(Spree.customer_class.table_name)

    add_column Spree.customer_class.table_name, :accepts_email_marketing, :boolean, default: false, null: false, if_not_exists: true
    add_index Spree.customer_class.table_name, :accepts_email_marketing, if_not_exists: true
  end
end
