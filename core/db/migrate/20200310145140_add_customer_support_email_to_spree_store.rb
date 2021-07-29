class AddCustomerSupportEmailToSpreeStore < ActiveRecord::Migration[5.2]
  def change
    unless column_exists?(:spree_stores, :customer_support_email)
      add_column :spree_stores, :customer_support_email, :string
    end
  end
end
