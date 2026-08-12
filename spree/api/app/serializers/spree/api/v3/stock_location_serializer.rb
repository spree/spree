module Spree
  module Api
    module V3
      class StockLocationSerializer < BaseSerializer
        typelize name: :string, address1: [:string, nullable: true], city: [:string, nullable: true],
                 zipcode: [:string, nullable: true], country_iso: [:string, nullable: true],
                 country_name: [:string, nullable: true], state_abbr: [:string, nullable: true],
                 state_text: [:string, nullable: true],
                 pickup_ready_in_minutes: [:number, nullable: true],
                 pickup_instructions: [:string, nullable: true]

        attribute :state_abbr do |stock_location|
          stock_location.state&.abbr
        end

        attributes :name, :address1, :city, :zipcode, :country_iso, :country_name, :state_text

        # Collection details the customer needs when choosing a counter: how
        # long until the order is ready, and where to go. This serializer
        # backs the pickup-locations endpoint, so without them the two
        # merchant-configured fields would never reach the buyer.
        attributes :pickup_ready_in_minutes, :pickup_instructions
      end
    end
  end
end
