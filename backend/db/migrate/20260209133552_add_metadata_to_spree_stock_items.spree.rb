# This migration comes from spree (originally 20220613133029)
class AddMetadataToSpreeStockItems < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_stock_items do |t|
      if t.respond_to? :jsonb
        add_column :spree_stock_items, :public_metadata, :jsonb
        add_column :spree_stock_items, :private_metadata, :jsonb
      else
        add_column :spree_stock_items, :public_metadata, :json
        add_column :spree_stock_items, :private_metadata, :json
      end
    end
  end
end
