module Spree
  module Admin
    class StockMovementsController < ResourceController
      belongs_to 'spree/stock_location', find_by: :id

      respond_to :html
    end
  end
end
