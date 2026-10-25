module Spree
  module Api
    module V3
      class StockLocationSerializer < BaseSerializer
        typelize name: :string, address1: [:string, nullable: true], city: [:string, nullable: true],
                 zipcode: [:string, nullable: true], country_code: [:string, nullable: true, enum: Spree::IsoData.country_codes, enum_type_name: 'CountryCode'],
                 country_name: [:string, nullable: true], state_code: [:string, nullable: true],
                 state_text: [:string, nullable: true],
                 country_iso: [:string, nullable: true, deprecated: 'Use `country_code`. Removed in 6.1.'],
                 state_abbr: [:string, nullable: true, deprecated: 'Use `state_code`. Removed in 6.1.'],
                 pickup_ready_in_minutes: [:number, nullable: true],
                 pickup_instructions: [:string, nullable: true]

        attributes :name, :address1, :city, :zipcode, :country_code, :country_name, :state_code, :state_text

        # @deprecated Storefronts shipped against these names; use +country_code+
        #   and +state_code+. Removed in 6.1.
        attribute :country_iso, &:country_code
        attribute :state_abbr, &:state_code

        # Collection details the customer needs when choosing a counter: how
        # long until the order is ready, and where to go. This serializer
        # backs the pickup-locations endpoint, so without them the two
        # merchant-configured fields would never reach the buyer.
        attributes :pickup_ready_in_minutes, :pickup_instructions
      end
    end
  end
end
