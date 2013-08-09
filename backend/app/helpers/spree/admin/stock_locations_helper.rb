module Spree
  module Admin
    module StockLocationsHelper
      def display_name(stock_location)
        name_parts = [stock_location.admin_name, stock_location.name]
        name_parts.delete_if(&:blank?)
        name_parts.join(' / ')
      end

      def state(stock_location)
        stock_location.active? ? 'active' : 'inactive'
      end
    end
  end
end