module Spree
  module Admin
    module StockMovementsHelper
      def pretty_originator(stock_movement)
        if stock_movement.originator.respond_to?(:number)
          link_to stock_movement.originator.number, [:edit, :admin, stock_movement.originator.order]
        else
          ""
        end
      end
    end
  end
end
