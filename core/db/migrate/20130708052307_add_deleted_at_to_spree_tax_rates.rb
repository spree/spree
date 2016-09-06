class AddDeletedAtToSpreeTaxRates < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_tax_rates, :deleted_at, :datetime
  end
end
