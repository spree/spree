class RenameDigitalsToDigitalAssets < ActiveRecord::Migration[8.1]
  def up
    rename_table :spree_digitals, :spree_digital_assets
    rename_column :spree_digital_links, :digital_id, :digital_asset_id

    # Null means "use the store's download settings". Per-asset values let one
    # catalog mix evergreen re-downloadable files with time-limited ones.
    add_column :spree_digital_assets, :authorized_clicks, :integer
    add_column :spree_digital_assets, :authorized_days, :integer
  end

  def down
    remove_column :spree_digital_assets, :authorized_days
    remove_column :spree_digital_assets, :authorized_clicks

    rename_column :spree_digital_links, :digital_asset_id, :digital_id
    rename_table :spree_digital_assets, :spree_digitals
  end
end
