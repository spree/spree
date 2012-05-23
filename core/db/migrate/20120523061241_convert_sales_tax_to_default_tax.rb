class ConvertSalesTaxToDefaultTax < ActiveRecord::Migration
  def up
    execute "UPDATE spree_calculators SET type='Spree::Calculator::DefaultTax' WHERE type='Spree::Calculator::SalesTax'"
  end

  def down
    execute "UPDATE spree_calculators SET type='Spree::Calculator::SalesTax' WHERE type='Spree::Calculator::DefaultTax'"
 end
end
