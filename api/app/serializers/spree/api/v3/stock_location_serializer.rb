module Spree
  module Api
    module V3
      class StockLocationSerializer < BaseSerializer
        attributes :id, :name, :address1, :city, :zipcode, :country_id, :country_iso, :country_name, :state_id, :state_text
      end
    end
  end
end
