module Spree
  module Admin
    class StockLocationsController < ResourceController
      before_action :set_country, only: :new

      private

      def set_country
        @stock_location.country = current_store.default_country
        unless @stock_location.country
          flash[:error] = Spree.t(:stock_locations_need_a_default_country)
          redirect_to spree.admin_stock_locations_path
        end
      end
    end
  end
end
