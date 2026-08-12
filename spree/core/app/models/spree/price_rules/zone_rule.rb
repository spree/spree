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
      # Held as ISO codes rather than country rows: Spree::Country is on its way
      # out, and "DE" is what a merchant means. Comma-separated input is split
      # and everything upcased, so a rule entered in lowercase still matches.
      #
      # Unlike MarketRule, an unknown code is not rejected — there is no country
      # table to check it against, and an unmatched code narrows the price list
      # to nothing rather than widening it.
      preference :country_isos, :array, default: [],
                 parse_on_set: lambda { |values, _owner = nil|
                   Array(values).
                     flat_map { |value| value.to_s.split(',') }.
                     compact_blank.
                     map { |iso| iso.strip.upcase }.
                     uniq
                 }

      def applicable?(context)
        return false if context.country_iso.blank?
        return true if preferred_country_isos.empty?

        preferred_country_isos.include?(context.country_iso.to_s.upcase)
      end

      # An empty country list matches every buyer (see #applicable?), so it names
      # no geography.
      def geographic?
        preferred_country_isos.present?
      end

      def self.description
        'Apply pricing based on the destination country'
      end
    end
  end
end
