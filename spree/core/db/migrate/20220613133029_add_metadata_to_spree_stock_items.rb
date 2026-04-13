class AddMetadataToSpreeStockItems < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_stock_items do |t|
      if t.respond_to? :jsonb
        add_column :spree_stock_items, :metadata, :jsonb
      else
        add_column :spree_stock_items, :metadata, :json
      end
    end
  end
end
