class AddFooterFieldsToSpreeStores < ActiveRecord::Migration[6.0]
  def change
      add_column :spree_stores, :description, :text
      add_column :spree_stores, :address, :text
      add_column :spree_stores, :contact_phone, :string
      add_column :spree_stores, :contact_email, :string
  end
end
