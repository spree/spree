module Spree
  module Admin
    module StockMovementsHelper
      def pretty_originator(stock_movement)
        if stock_movement.originator.respond_to?(:number)
          stock_movement.originator.number
        else
          ""
        end
      end
    end
  end
end
