class AddTaxRateLabel < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_tax_rates, :name, :string
  end
end
