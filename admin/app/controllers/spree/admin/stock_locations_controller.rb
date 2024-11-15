module Spree
  module Admin
    class StockLocationsController < ResourceController
      before_action :set_country, only: :new

      def mark_as_default
        @stock_location.update(default: true)

        flash[:success] = flash_message_for(@stock_location, :marked_as_default)
        redirect_to spree.admin_stock_locations_path
      end

      private

      def collection
        super.order_default
      end

      def set_country
        @stock_location.country = current_store.default_country
      end
    end
  end
end
