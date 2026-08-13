module Spree
  module Seeds
    # Seeds the legacy tax zones by name only.
    #
    # Zone members addressed countries by row id, and countries are reference
    # data rather than records in 6.0, so there are no ids to point at. The
    # zones are created empty and match nothing until the tax provider replaces
    # them (docs/plans/6.0-tax-provider.md Phase 5). Shipping geography is
    # seeded as delivery zones instead — see Spree::Seeds::DeliveryZones.
    class Zones
      prepend Spree::ServiceModule::Base

      ZONES = [
        { name: 'EU_VAT', description: 'Countries that make up the EU VAT zone.' },
        { name: 'UK_VAT', description: nil },
        { name: 'North America', description: 'USA + Canada' },
        { name: 'Central America and Caribbean', description: 'Central America and Caribbean' },
        { name: 'South America', description: 'South America' },
        { name: 'Middle East', description: 'Middle East' },
        { name: 'Africa', description: 'Africa' },
        { name: 'Asia', description: 'Asia' },
        { name: 'Australia and Oceania', description: 'Australia and Oceania' }
      ].freeze

      def call
        ZONES.each do |attributes|
          Spree::Zone.where(name: attributes[:name]).first_or_create! do |zone|
            zone.description = attributes[:description]
            zone.kind = 'country'
          end
        end
      end
    end
  end
end
