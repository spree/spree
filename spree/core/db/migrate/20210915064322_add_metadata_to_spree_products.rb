class AddMetadataToSpreeProducts < ActiveRecord::Migration[5.2]
  def change
    change_table :spree_products do |t|
      if t.respond_to? :jsonb
        add_column :spree_products, :metadata, :jsonb
      else
        add_column :spree_products, :metadata, :json
      end
    end
  end
end
