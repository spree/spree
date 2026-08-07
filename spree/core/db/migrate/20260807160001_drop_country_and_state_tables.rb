class DropCountryAndStateTables < ActiveRecord::Migration[7.2]
  def up
    # Countries and states are reference data supplied by the countries gem in
    # 6.0 (docs/plans/6.0-drop-country-state-models.md); every consumer names
    # them by ISO code, backfilled by spree:upgrade:migrate_country_state_isos.
    remove_column :spree_addresses, :country_id
    remove_column :spree_addresses, :state_id

    remove_column :spree_delivery_zone_members, :country_id
    remove_column :spree_delivery_zone_members, :state_id

    remove_column :spree_market_countries, :country_id

    remove_column :spree_stock_locations, :country_id
    remove_column :spree_stock_locations, :state_id

    remove_column :spree_stores, :default_country_id

    drop_table :spree_states
    drop_table :spree_countries
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Countries and states are no longer database-backed; restore from a backup to go back.'
  end
end
