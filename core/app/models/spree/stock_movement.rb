module Spree
  class StockMovement < ActiveRecord::Base
    belongs_to :stock_item

    attr_accessible :action, :quantity
  end
end
