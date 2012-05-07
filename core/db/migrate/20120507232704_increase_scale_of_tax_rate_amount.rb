class IncreaseScaleOfTaxRateAmount < ActiveRecord::Migration
  def up
    change_column :spree_tax_rates, :amount, :decimal, { :scale => 5, :precision => 8 }
  end

  def down
    change_column :spree_tax_rates, :amount, :decimal, { :scale => 4, :precision => 8 }
  end
end
