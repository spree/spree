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
    # state-kind zone. Resolved through the live tables so a member pointing at
    # a deleted country or state drops out.
    def country_list
      Spree::Country.where(
        id: zone_members.where(zoneable_type: 'Spree::Country').select(:zoneable_id)
      ).or(
        Spree::Country.where(
          id: Spree::State.where(
            id: zone_members.where(zoneable_type: 'Spree::State').select(:zoneable_id)
          ).select(:country_id)
        )
      )
    end
  end
end
