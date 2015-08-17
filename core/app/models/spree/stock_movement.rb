module Spree
  class StockMovement < Spree::Base
    belongs_to :stock_item, class_name: 'Spree::StockItem', inverse_of: :stock_movements
    belongs_to :originator, polymorphic: true

    after_create :update_stock_item_quantity

    validates :stock_item, presence: true
    validates :quantity, presence: true, numericality: {
                 greater_than_or_equal_to: -2**31,
                 less_than_or_equal_to: 2**31-1,
                 only_integer: true,
                 allow_nil: true
              }

    scope :recent, -> { order('created_at DESC') }

    self.whitelisted_ransackable_attributes = ['quantity']

    def readonly?
      !new_record?
    end

    private

    def update_stock_item_quantity
      return unless self.stock_item.should_track_inventory?
      stock_item.adjust_count_on_hand quantity
    end

  end
end

