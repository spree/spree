class AddIncTaxToTaxRates < ActiveRecord::Migration
  def change
    add_column :spree_tax_rates, :inc_tax, :boolean, :default => false
  end
end
