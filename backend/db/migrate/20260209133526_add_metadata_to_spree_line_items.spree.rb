# This migration comes from spree (originally 20210915064324)
class AddMetadataToSpreeLineItems < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_line_items do |t|
      if t.respond_to? :jsonb
        add_column :spree_line_items, :public_metadata, :jsonb
        add_column :spree_line_items, :private_metadata, :jsonb
      else
        add_column :spree_line_items, :public_metadata, :json
        add_column :spree_line_items, :private_metadata, :json
      end
    end
  end
end
