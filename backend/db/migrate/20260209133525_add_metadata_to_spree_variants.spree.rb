# This migration comes from spree (originally 20210915064323)
class AddMetadataToSpreeVariants < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_variants do |t|
      if t.respond_to? :jsonb
        add_column :spree_variants, :public_metadata, :jsonb
        add_column :spree_variants, :private_metadata, :jsonb
      else
        add_column :spree_variants, :public_metadata, :json
        add_column :spree_variants, :private_metadata, :json
      end
    end
  end
end
