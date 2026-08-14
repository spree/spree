module Spree
  class StockMovement < Spree.base_class
    has_prefix_id :sm

    QUANTITY_LIMITS = {
      max: 2**31 - 1,
      min: -2**31
    }.freeze

    include Spree::StockMovement::CustomEvents

    publishes_lifecycle_events

    belongs_to :stock_level, class_name: 'Spree::StockLevel', inverse_of: :stock_movements
    belongs_to :originator, polymorphic: true

    alias_attribute :stock_item_id, :stock_level_id

    after_create :update_stock_level_quantity

    with_options presence: true do
      validates :stock_level
      validates :quantity, numericality: {
        greater_than_or_equal_to: :min_quantity,
        less_than_or_equal_to: QUANTITY_LIMITS[:max],
        only_integer: true
      }
    end

    scope :recent, -> { order(created_at: :desc) }

    delegate :variant, :variant_id, to: :stock_level, allow_nil: true
    delegate :product, to: :variant

    self.whitelisted_ransackable_attributes = %w[quantity action created_at stock_level_id originator_type]
    self.whitelisted_ransackable_associations = %w[stock_level]

    def readonly?
      persisted?
    end

    # @deprecated Use {#stock_level}; removed in 6.1.
    def stock_item
      Spree::Deprecation.warn('Spree::StockMovement#stock_item is deprecated and will be removed in Spree 6.1. Use #stock_level instead.')
      stock_level
    end

    # @deprecated Use {#stock_level=}; removed in 6.1.
    def stock_item=(record)
      Spree::Deprecation.warn('Spree::StockMovement#stock_item= is deprecated and will be removed in Spree 6.1. Use #stock_level= instead.')
      self.stock_level = record
    end

    private

    def update_stock_level_quantity
      return unless stock_level.should_track_inventory?

      stock_level.adjust_count_on_hand quantity
    end

    def min_quantity
      return QUANTITY_LIMITS[:min] if stock_level.nil? || stock_level.backorderable?

      -stock_level.count_on_hand
    end
  end
end
