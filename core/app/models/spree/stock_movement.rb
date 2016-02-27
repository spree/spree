module Spree
  class StockMovement < Spree::Base

    MAX_QUANTITY = 2147483647
    MIN_QUANTITY = -2147483648

    belongs_to :stock_item, class_name: 'Spree::StockItem', inverse_of: :stock_movements
    belongs_to :originator, polymorphic: true

    after_create :update_stock_item_quantity

    with_options presence: true do
      validates :stock_item
      validates :quantity, numericality: {
                                            greater_than_or_equal_to: MIN_QUANTITY,
                                            less_than_or_equal_to: MAX_QUANTITY,
                                            only_integer: true,
                                            allow_nil: true
                                          }
    end

    scope :recent, -> { order(created_at: :desc) }

    self.whitelisted_ransackable_attributes = ['quantity']

    def readonly?
      persisted?
    end

    private

    def update_stock_item_quantity
      return unless self.stock_item.should_track_inventory?
      stock_item.adjust_count_on_hand quantity
    end

  end
end

