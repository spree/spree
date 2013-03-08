module Spree
  module Admin
    module StockMovementsHelper
      def allowed_stock_movement_actions
        %w{sold received}
      end
    end
  end
end
