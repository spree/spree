class AddAddressFieldsToStockLocation < ActiveRecord::Migration
  def change
    remove_column :spree_stock_locations, :address_id

    add_column :spree_stock_locations, :address1, :string
    add_column :spree_stock_locations, :address2, :string
    add_column :spree_stock_locations, :city, :string
    add_column :spree_stock_locations, :state_id, :integer
    add_column :spree_stock_locations, :state_name, :string
    add_column :spree_stock_locations, :country_id, :integer
    add_column :spree_stock_locations, :zipcode, :string
    add_column :spree_stock_locations, :phone, :string
  end
end
