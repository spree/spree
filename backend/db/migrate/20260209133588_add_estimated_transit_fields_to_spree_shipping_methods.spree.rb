# This migration comes from spree (originally 20241123110646)
class AddEstimatedTransitFieldsToSpreeShippingMethods < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_shipping_methods, :estimated_transit_business_days_min, :integer
    add_column :spree_shipping_methods, :estimated_transit_business_days_max, :integer
  end
end
