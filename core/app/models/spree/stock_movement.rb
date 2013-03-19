module Spree
  class StockMovement < ActiveRecord::Base
    belongs_to :stock_item
    belongs_to :source, polymorphic: true
    belongs_to :destination, polymorphic: true

    attr_accessible :quantity, :stock_item, :stock_item_id

    before_save :update_stock_item_quantity

    validates :stock_item, presence: true
    validates :quantity, presence: true

    private

    def update_stock_item_quantity
      changes = self.changes["quantity"]
      if changes.present?
        original = changes[0]
        final = changes[1]

        original = 0 if original.nil?
        stock_item.count_on_hand = stock_item.count_on_hand - original + final
        stock_item.save
      end
    end
  end
end
