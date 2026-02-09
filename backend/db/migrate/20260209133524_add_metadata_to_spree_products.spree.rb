# This migration comes from spree (originally 20210915064322)
class AddMetadataToSpreeProducts < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_products do |t|
      if t.respond_to? :jsonb
        add_column :spree_products, :public_metadata, :jsonb
        add_column :spree_products, :private_metadata, :jsonb
      else
        add_column :spree_products, :public_metadata, :json
        add_column :spree_products, :private_metadata, :json
      end
    end
  end
end
