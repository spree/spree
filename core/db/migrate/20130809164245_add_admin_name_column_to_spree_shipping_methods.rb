class AddAdminNameColumnToSpreeShippingMethods < ActiveRecord::Migration
  def change
    add_column :spree_shipping_methods, :admin_name, :string
  end
end
