class ChangeOrdersTotalPrecision < ActiveRecord::Migration
   def change
    change_column :spree_orders, :item_total,  :decimal, :precision => 10, :scale => 2, :default => 0.0, :null => false
    change_column :spree_orders, :total,  :decimal, :precision => 10, :scale => 2, :default => 0.0, :null => false
    change_column :spree_orders, :adjustment_total,  :decimal, :precision => 10, :scale => 2, :default => 0.0, :null => false
    change_column :spree_orders, :payment_total,  :decimal, :precision => 10, :scale => 2, :default => 0.0                                
   end
end
