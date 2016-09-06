class AddTaxRateIdToShippingRates < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_shipping_rates, :tax_rate_id, :integer
  end
end
