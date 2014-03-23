class AddTaxRateIdToShippingRates < ActiveRecord::Migration
  def change
    add_column :spree_shipping_rates, :tax_rate_id, :integer
  end
end
