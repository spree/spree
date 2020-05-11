class AddFooterFieldsToSpreeStores < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_stores, :description, :text unless column_exists?(:spree_stores, :description)
    add_column :spree_stores, :address, :text unless column_exists?(:spree_stores, :address)
    add_column :spree_stores, :contact_phone, :string unless column_exists?(:spree_stores, :contact_phone)
    add_column :spree_stores, :contact_email, :string unless column_exists?(:spree_stores, :contact_email)
  end
end
