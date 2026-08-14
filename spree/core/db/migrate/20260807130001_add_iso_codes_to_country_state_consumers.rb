class AddIsoCodesToCountryStateConsumers < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_addresses, :country_iso, :string
    add_column :spree_addresses, :state_code, :string
    add_index :spree_addresses, :country_iso

    # State members carry their country too: a subdivision code is only unique
    # within its country ("CA" is California and several other things), and
    # coverage queries would otherwise need the states table to resolve it.
    add_column :spree_delivery_zone_members, :country_iso, :string
    add_column :spree_delivery_zone_members, :state_code, :string
    add_index :spree_delivery_zone_members, :country_iso

    add_column :spree_market_countries, :country_iso, :string
    add_index :spree_market_countries, [:market_id, :country_iso],
              unique: true, name: 'index_spree_market_countries_on_market_id_and_country_iso'

    # The country foreign key stays until 6.1 so the upgrade task keeps its
    # source data, but nothing writes it any more — a market country is
    # identified by its ISO code now.
    change_column_null :spree_market_countries, :country_id, true

    add_column :spree_stock_locations, :country_iso, :string
    add_column :spree_stock_locations, :state_code, :string

    # Not `default_country_iso`, which is already a virtual attribute on Store.
    add_column :spree_stores, :default_country_iso_code, :string
  end
end
