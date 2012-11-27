class AddTaxRateLabel < ActiveRecord::Migration
  def change
    add_column :spree_tax_rates, :name, :string
  end
end
