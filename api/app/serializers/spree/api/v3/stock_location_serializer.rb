module Spree
  module Api
    module V3
      class StockLocationSerializer < BaseSerializer
        typelize name: :string, address1: 'string | null', city: 'string | null',
                 zipcode: 'string | null', country_id: 'string | null',
                 country_iso: 'string | null', country_name: 'string | null',
                 state_id: 'string | null', state_text: 'string | null'

        attribute :country_id do |stock_location|
          stock_location.country&.prefix_id
        end

        attribute :state_id do |stock_location|
          stock_location.state&.prefix_id
        end

        attributes :name, :address1, :city, :zipcode, :country_iso, :country_name, :state_text
      end
    end
  end
end
