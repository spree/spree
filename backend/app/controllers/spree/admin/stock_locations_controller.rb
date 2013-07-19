module Spree
  module Admin
    class StockLocationsController < ResourceController

      new_action.before :set_country

      private

      def set_country
        if Spree::Config[:default_country_id].present?
          @stock_location.country = Spree::Country.find(Spree::Config[:default_country_id])
        else
          @stock_location.country = Spree::Country.find_by_iso('US')
        end
      end

    end
  end
end
