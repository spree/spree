# This migration comes from spree (originally 20250114193857)
class AddMetadataToSpreeStores < ActiveRecord::Migration[6.1]
  def change
    change_table :spree_stores do |t|
      if t.respond_to? :jsonb
        add_column :spree_stores, :public_metadata, :jsonb
        add_column :spree_stores, :private_metadata, :jsonb
      else
        add_column :spree_stores, :public_metadata, :json
        add_column :spree_stores, :private_metadata, :json
      end
    end
  end
end
