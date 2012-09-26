class AddSellableField < ActiveRecord::Migration
  def change
    add_column :spree_products, :sellable, :boolean, :default => true
  end
end
