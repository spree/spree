# This migration comes from spree (originally 20210915064328)
class AddMetadataToSpreeStockTransfers < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_stock_transfers do |t|
      if t.respond_to? :jsonb
        add_column :spree_stock_transfers, :public_metadata, :jsonb
        add_column :spree_stock_transfers, :private_metadata, :jsonb
      else
        add_column :spree_stock_transfers, :public_metadata, :json
        add_column :spree_stock_transfers, :private_metadata, :json
      end
    end
  end
end
