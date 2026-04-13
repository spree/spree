class AddMetadataToSpreeStockTransfers < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_stock_transfers do |t|
      if t.respond_to? :jsonb
        add_column :spree_stock_transfers, :metadata, :jsonb
      else
        add_column :spree_stock_transfers, :metadata, :json
      end
    end
  end
end
