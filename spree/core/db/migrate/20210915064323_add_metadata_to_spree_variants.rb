class AddMetadataToSpreeVariants < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_variants do |t|
      if t.respond_to? :jsonb
        add_column :spree_variants, :metadata, :jsonb
      else
        add_column :spree_variants, :metadata, :json
      end
    end
  end
end
