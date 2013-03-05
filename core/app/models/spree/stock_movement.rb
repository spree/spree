module Spree
  class StockMovement < ActiveRecord::Base
    belongs_to :stock_item

    attr_accessible :action, :quantity

    after_save :update_stock_item_quantity

    validates :action, inclusion: { in: %w(sold received), message: "%{value} is not a valid action" }

    private

    def update_stock_item_quantity
      variant = stock_item.variant

      if action == "sold"
        stock_item.stock_location.decrease_stock_for_variant(variant, -quantity)
      else
        stock_item.stock_location.increase_stock_for_variant(variant, quantity)
      end
    end
  end
end
