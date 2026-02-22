module Spree
  module Api
    module V3
      class StockLocationSerializer < BaseSerializer
        typelize name: :string, address1: [:string, nullable: true], city: [:string, nullable: true],
                 zipcode: [:string, nullable: true], country_iso: [:string, nullable: true],
                 country_name: [:string, nullable: true], state_abbr: [:string, nullable: true],
                 state_text: [:string, nullable: true]

        attribute :state_abbr do |stock_location|
          stock_location.state&.abbr
        end

        attributes :name, :address1, :city, :zipcode, :country_iso, :country_name, :state_text
      end
    end
  end
end
