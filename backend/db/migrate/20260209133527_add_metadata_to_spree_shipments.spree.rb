# This migration comes from spree (originally 20210915064325)
class AddMetadataToSpreeShipments < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_shipments do |t|
      if t.respond_to? :jsonb
        add_column :spree_shipments, :public_metadata, :jsonb
        add_column :spree_shipments, :private_metadata, :jsonb
      else
        add_column :spree_shipments, :public_metadata, :json
        add_column :spree_shipments, :private_metadata, :json
      end
    end
  end
end
