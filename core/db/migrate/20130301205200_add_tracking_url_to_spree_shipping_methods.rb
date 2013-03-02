class AddTrackingUrlToSpreeShippingMethods < ActiveRecord::Migration
  def change
    add_column :spree_shipping_methods, :tracking_url, :string
  end
end
