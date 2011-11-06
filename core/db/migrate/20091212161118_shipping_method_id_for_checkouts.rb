class ShippingMethodIdForCheckouts < ActiveRecord::Migration
  def change
    add_column :checkouts, :shipping_method_id, :integer
  end
end
