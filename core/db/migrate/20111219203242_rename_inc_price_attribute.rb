class RenameIncPriceAttribute < ActiveRecord::Migration
  def change
    rename_column :spree_tax_rates, :inc_tax, :included_in_price
  end
end
