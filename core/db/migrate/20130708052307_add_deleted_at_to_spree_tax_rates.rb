class AddDeletedAtToSpreeTaxRates < ActiveRecord::Migration
  def change
    add_column :spree_tax_rates, :deleted_at, :datetime
  end
end
