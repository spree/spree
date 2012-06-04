class AddDeletedAtToSpreeShippingMethods < ActiveRecord::Migration
  def change
    add_column :spree_shipping_methods, :deleted_at, :datetime
  end
end
