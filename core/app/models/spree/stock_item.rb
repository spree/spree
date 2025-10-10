module Spree
  class StockItem < Spree.base_class
    acts_as_paranoid

    include Spree::Metafields
    include Spree::Metadata
    include Spree::StockItem::Webhooks

    with_options inverse_of: :stock_items do
      belongs_to :stock_location, class_name: 'Spree::StockLocation'
      belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant'
    end
    has_many :stock_movements, inverse_of: :stock_item

    validates :stock_location, :variant, presence: true
    validates :variant_id, uniqueness: { scope: :stock_location_id }, unless: :deleted_at

    validates :count_on_hand, numericality: {
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 2**31 - 1,
      only_integer: true
    }, if: :verify_count_on_hand?

    delegate :weight, :should_track_inventory?, to: :variant
    delegate :name, to: :variant, prefix: true
    delegate :product, to: :variant

    after_save :conditional_variant_touch, if: :saved_changes?
    after_touch { variant.touch }
    after_destroy { variant.touch }

    self.whitelisted_ransackable_attributes = %w[count_on_hand stock_location_id variant_id]
    self.whitelisted_ransackable_associations = %w[variant stock_location]

    scope :with_active_stock_location, -> { joins(:stock_location).merge(Spree::StockLocation.active) }

    def backordered_inventory_units
      Spree::InventoryUnit.backordered_for_stock_item(self)
    end

    def adjust_count_on_hand(value)
      with_lock do
        set_count_on_hand(count_on_hand + value)
      end
    end

    def set_count_on_hand(value)
      self.count_on_hand = value
      process_backorders(count_on_hand - count_on_hand_was)

      save!
    end

    def in_stock?
      count_on_hand > 0
    end

    # Tells whether it's available to be included in a shipment
    def available?
      in_stock? || backorderable?
    end

    def reduce_count_on_hand_to_zero
      set_count_on_hand(0) if count_on_hand > 0
    end

    private

    def verify_count_on_hand?
      count_on_hand_changed? && !backorderable? && (count_on_hand < count_on_hand_was) && (count_on_hand < 0)
    end

    # Process backorders based on amount of stock received
    # If stock was -20 and is now -15 (increase of 5 units), then we can process atmost 5 inventory orders.
    # If stock was -20 but then was -25 (decrease of 5 units), do nothing.
    def process_backorders(number)
      return unless number.positive?

      units = backordered_inventory_units.first(number) # We can process atmost n backorders

      units.each do |unit|
        break unless number.positive?

        if unit.quantity > number
          # if required quantity is greater than available
          # split off and fulfill that
          split = unit.split_inventory!(number)
          split.fill_backorder
        else
          unit.fill_backorder
        end
        number -= unit.quantity
      end
    end

    def conditional_variant_touch
      variant.touch if !Spree::Config.binary_inventory_cache || stock_changed?
    end

    def stock_changed?
      # the variant_id changes from nil when a new stock location is added
      (
        saved_change_to_count_on_hand? &&
        saved_change_to_count_on_hand.any?(&:zero?)
      ) || saved_change_to_variant_id?
    end
  end
end
