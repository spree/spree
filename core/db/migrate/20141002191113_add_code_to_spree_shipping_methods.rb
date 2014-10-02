class AddCodeToSpreeShippingMethods < ActiveRecord::Migration
  def change
    add_column :spree_shipping_methods, :code, :string
  end
end
