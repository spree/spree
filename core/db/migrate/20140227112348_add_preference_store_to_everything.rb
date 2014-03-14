class AddPreferenceStoreToEverything < ActiveRecord::Migration
  def change
    add_column :spree_calculators, :preferences, :text
    add_column :spree_gateways, :preferences, :text
    add_column :spree_payment_methods, :preferences, :text
    add_column :spree_promotion_rules, :preferences, :text
  end
end
