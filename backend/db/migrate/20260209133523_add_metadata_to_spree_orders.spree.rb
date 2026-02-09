# This migration comes from spree (originally 20210915064321)
class AddMetadataToSpreeOrders < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_orders do |t|
      if t.respond_to? :jsonb
        add_column :spree_orders, :public_metadata, :jsonb
        add_column :spree_orders, :private_metadata, :jsonb
      else
        add_column :spree_orders, :public_metadata, :json
        add_column :spree_orders, :private_metadata, :json
      end
    end
  end
end
