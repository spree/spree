class AddStoreToDeliveryMethodsAndStockLocations < ActiveRecord::Migration[7.2]
  def change
    add_reference :spree_delivery_methods, :store
    add_reference :spree_stock_locations, :store
  end
end
