module Spree
  class StockMovement < Spree.base_class
    QUANTITY_LIMITS = {
      max: 2**31 - 1,
      min: -2**31
    }.freeze

    include Spree::StockMovement::Webhooks
    include Spree::StockMovement::CustomEvents

    publishes_lifecycle_events

    belongs_to :stock_item, class_name: 'Spree::StockItem', inverse_of: :stock_movements
    belongs_to :originator, polymorphic: true

    after_create :update_stock_item_quantity

    with_options presence: true do
      validates :stock_item
      validates :quantity, numericality: {
        greater_than_or_equal_to: :min_quantity,
        less_than_or_equal_to: QUANTITY_LIMITS[:max],
        only_integer: true
      }
    end

    scope :recent, -> { order(created_at: :desc) }

    delegate :variant, :variant_id, to: :stock_item, allow_nil: true
    delegate :product, to: :variant

    self.whitelisted_ransackable_attributes = ['quantity']

    def readonly?
      persisted?
    end

    private

    def update_stock_item_quantity
      return unless stock_item.should_track_inventory?

      stock_item.adjust_count_on_hand quantity
    end

    def min_quantity
      return QUANTITY_LIMITS[:min] if stock_item.nil? || stock_item.backorderable?

      -stock_item.count_on_hand
    end
  end
end
