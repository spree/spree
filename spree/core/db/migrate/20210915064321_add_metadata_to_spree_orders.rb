class AddMetadataToSpreeOrders < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_orders do |t|
      if t.respond_to? :jsonb
        add_column :spree_orders, :metadata, :jsonb
      else
        add_column :spree_orders, :metadata, :json
      end
    end
  end
end
