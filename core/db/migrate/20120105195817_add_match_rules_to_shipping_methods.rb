class AddMatchRulesToShippingMethods < ActiveRecord::Migration
  def change
    add_column :spree_shipping_methods, :match_none, :boolean
    add_column :spree_shipping_methods, :match_all, :boolean
    add_column :spree_shipping_methods, :match_one, :boolean
  end
end
