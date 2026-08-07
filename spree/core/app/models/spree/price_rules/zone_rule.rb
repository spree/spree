module Spree
  module PriceRules
    # Restricts a price list by where the buyer is. Named for the zones it read
    # before 6.0: tax and pricing no longer speak in zones, so eligibility is
    # decided by country and `spree:migrate_tax_zones` restates each row's
    # stored zones as the countries they contained. The class name stays because
    # it is persisted in the +type+ column.
    #
    # Kept out of the default registry, so it never appears under "Add rule" —
    # MarketRule covers geography for new price lists. Whether this becomes a
    # first-class country rule belongs to docs/plans/6.0-delivery-zones.md,
    # which owns the removal of Zone itself.
    class ZoneRule < Spree::PriceRule
      # Stored as raw IDs. Accepts prefixed IDs from API callers and decodes
      # them on write, so eligibility compares against raw country_id rows.
      # Countries are global reference data, so unlike MarketRule there is no
      # store scope to confine the existence check to.
      preference :country_ids, :array, default: [],
                 parse_on_set: normalize_id_preference(klass: Spree::Country)

      def applicable?(context)
        return false unless context.country
        return true if preferred_country_ids.empty?

        # Compare as strings to support both integer and UUID primary keys
        preferred_country_ids.map(&:to_s).include?(context.country.id.to_s)
      end

      def self.description
        'Apply pricing based on the destination country'
      end
    end
  end
end
