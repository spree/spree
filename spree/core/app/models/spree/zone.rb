module Spree
  # Migration-only shell, removed in Spree 6.1 together with its tables.
  # Delivery coverage lives on {Spree::DeliveryZone}, tax rates carry their own
  # country and state codes, and zone-scoped price rules were converted to
  # market rules (or their lists deactivated) — nothing at runtime reads a
  # zone. The
  # class survives only so the 5.6→6.0 upgrade tasks
  # (`spree:migrate_tax_zones`, `spree:migrate_zones_to_delivery_zones`,
  # `spree:backfill_order_markets`) can still read the rows they convert.
  class Zone < Spree.base_class
    has_many :zone_members, class_name: 'Spree::ZoneMember', dependent: :destroy, inverse_of: :zone
    alias members zone_members

    # The countries the zone contained — directly, or through its states for a
    # state-kind zone.
    #
    # Reads spree_countries and spree_states directly: countries and states are
    # reference data rather than records in 6.0
    # (docs/plans/6.0-drop-country-state-models.md), so the ids these members
    # hold can only be resolved against the tables the upgrade keeps. A member
    # pointing at a row that no longer exists drops out.
    #
    # @return [Array<Spree::Country>]
    def country_list
      connection = self.class.connection
      return [] unless connection.table_exists?('spree_countries')

      country_ids = zone_members.where(zoneable_type: 'Spree::Country').pluck(:zoneable_id)
      state_ids = zone_members.where(zoneable_type: 'Spree::State').pluck(:zoneable_id)

      isos = []
      isos.concat(isos_for_country_ids(connection, country_ids)) if country_ids.any?
      isos.concat(isos_for_state_ids(connection, state_ids)) if state_ids.any?

      isos.uniq.filter_map { |iso| Spree::Country.by_iso(iso) }
    end

    private

    def isos_for_country_ids(connection, ids)
      connection.select_values(
        "SELECT iso FROM spree_countries WHERE id IN (#{ids.map { |id| connection.quote(id) }.join(', ')})"
      )
    end

    def isos_for_state_ids(connection, ids)
      return [] unless connection.table_exists?('spree_states')

      connection.select_values(<<~SQL.squish)
        SELECT spree_countries.iso FROM spree_states
        INNER JOIN spree_countries ON spree_countries.id = spree_states.country_id
        WHERE spree_states.id IN (#{ids.map { |id| connection.quote(id) }.join(', ')})
      SQL
    end
  end
end
