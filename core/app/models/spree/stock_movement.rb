module Spree
  class StockMovement < ActiveRecord::Base
    belongs_to :stock_item
  end
end
