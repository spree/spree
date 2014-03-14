class RemoveCountriesAndStates < ActiveRecord::Migration
  def up
    add_column :spree_addresses, :country_code, :string
    add_column :spree_addresses, :region_code, :string
    add_column :spree_stock_locations, :country_code, :string
    add_column :spree_stock_locations, :region_code, :string
    add_column :spree_zone_members, :country_code, :string
    add_column :spree_zone_members, :region_code, :string

    execute %{
      update spree_addresses
      set country_code = spree_countries.iso
        , region_code = spree_states.abbr
      from spree_countries, spree_states
      where (spree_addresses.country_id is null or spree_addresses.country_id = spree_countries.id)
        and (spree_addresses.state_id is null or spree_addresses.state_id = spree_states.id)
    }

    execute %{
      update spree_stock_locations
      set country_code = spree_countries.iso
        , region_code = spree_states.abbr
      from spree_countries, spree_states
      where (spree_stock_locations.country_id is null or spree_stock_locations.country_id = spree_countries.id)
        and (spree_stock_locations.state_id is null or spree_stock_locations.state_id = spree_states.id)
    }

    execute %{
      update spree_zone_members
      set country_code = spree_countries.iso
      from spree_countries
      where spree_zone_members.zoneable_type = 'Spree::Country'
        and spree_zone_members.zoneable_id = spree_countries.id
    }

    execute %{
      update spree_zone_members
      set country_code = spree_countries.iso
        , region_code = spree_states.abbr
      from spree_countries, spree_states
      where spree_zone_members.zoneable_type = 'Spree::State'
        and spree_zone_members.zoneable_id = spree_states.id
        and spree_states.country_id = spree_countries.id
    }

    #TODO: handle when just state name set? does that happen?

    remove_column :spree_addresses, :country_id
    remove_column :spree_addresses, :state_id
    remove_column :spree_addresses, :state_name

    remove_column :spree_stock_locations, :country_id
    remove_column :spree_stock_locations, :state_id
    remove_column :spree_stock_locations, :state_name

    remove_column :spree_zone_members, :zoneable_id
    remove_column :spree_zone_members, :zoneable_type

    drop_table :spree_states
    drop_table :spree_countries
  end

  def down
    #Can't roll back since we probably can't recreate the table data
    raise 'Rolling back this migration not supported.'
  end
end
