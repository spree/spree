module Spree
  class StockMovement < ActiveRecord::Base
    belongs_to :stock_item

    attr_accessible :action, :quantity

    after_save :update_stock_item_quantity

    validates :action, inclusion: { in: %w(sold received), message: "%{value} is not a valid action" }

    private

    def update_stock_item_quantity
      if action == "sold"
        stock_item.count_on_hand -= quantity
      else
        stock_item.count_on_hand += quantity
      end
    end
  end
end
