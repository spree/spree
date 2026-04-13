class AddMetadataToSpreeStores < ActiveRecord::Migration[6.1]
  def change
    change_table :spree_stores do |t|
      if t.respond_to? :jsonb
        add_column :spree_stores, :metadata, :jsonb
      else
        add_column :spree_stores, :metadata, :json
      end
    end
  end
end
