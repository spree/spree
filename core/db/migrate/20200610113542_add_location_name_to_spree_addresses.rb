class AddLocationNameToSpreeAddresses < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_addresses, :location_name, :string unless column_exists?(:spree_addresses, :location_name)
  end
end
