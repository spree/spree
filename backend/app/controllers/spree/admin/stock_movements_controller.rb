module Spree
  module Admin
    class StockMovementsController < ResourceController
      belongs_to 'spree/stock_location', find_by: :id

      respond_to :html
      helper_method :allowed_actions

      def allowed_actions
        %w{received sold}
      end
    end
  end
end
