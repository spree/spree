class AddProviderTypeToSpreeDigitalAssets < ActiveRecord::Migration[8.1]
  def change
    # Nullable: a blank provider_type means the File provider (an uploaded
    # file), so every existing row keeps its behaviour with no backfill.
    add_column :spree_digital_assets, :provider_type, :string
  end
end
