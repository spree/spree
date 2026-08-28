class AddMetadataToSpreeDigitalAssets < ActiveRecord::Migration[8.1]
  def change
    change_table :spree_digital_assets do |t|
      if t.respond_to?(:jsonb)
        add_column :spree_digital_assets, :metadata, :jsonb
      else
        add_column :spree_digital_assets, :metadata, :json
      end
    end
  end
end
