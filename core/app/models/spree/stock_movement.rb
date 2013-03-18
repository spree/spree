module Spree
  class StockMovement < ActiveRecord::Base
    belongs_to :stock_item
    belongs_to :source, polymorphic: true
    belongs_to :destination, polymorphic: true

    attr_accessible :action, :quantity, :stock_item, :stock_item_id

    before_save :update_stock_item_quantity

    validates :action, inclusion: { in: %w(sold received), message: "%{value} is not a valid action" }
    validates :stock_item, presence: true
    validates :quantity, presence: true, numericality: { greater_than: 0 }

    private

    def update_stock_item_quantity
      changes = self.changes["quantity"]
      if changes.present?
        original = changes[0]
        final = changes[1]

        original = 0 if original.nil?

        if action == "sold"
          stock_item.count_on_hand = stock_item.count_on_hand + original - final
        else
          stock_item.count_on_hand = stock_item.count_on_hand - original + final
        end
        stock_item.save
      end
    end
  end
end
