class AddEstimatedTransitFieldsToSpreeShippingMethods < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_shipping_methods, :estimated_transit_business_days_min, :integer
    add_column :spree_shipping_methods, :estimated_transit_business_days_max, :integer
  end
end
