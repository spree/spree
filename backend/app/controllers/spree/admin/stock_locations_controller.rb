require 'carmen'

module Spree
  module Admin
    class StockLocationsController < ResourceController

      new_action.before :set_country

      private
        def set_country
          @stock_location.country_code = Carmen::Country.coded(Spree::Config[:default_country_code] || 'US').code
        end
    end
  end
end
