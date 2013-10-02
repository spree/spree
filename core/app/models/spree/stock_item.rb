module Spree
  class StockItem < ActiveRecord::Base
    acts_as_paranoid

    belongs_to :stock_location, class_name: 'Spree::StockLocation'
    belongs_to :variant, class_name: 'Spree::Variant'
    has_many :stock_movements

    validates_presence_of :stock_location, :variant
    validates_uniqueness_of :variant_id, scope: :stock_location_id

    attr_accessible :count_on_hand, :variant, :stock_location, :backorderable, :variant_id

    delegate :weight, to: :variant

    def backordered_inventory_units
      Spree::InventoryUnit.backordered_for_stock_item(self)
    end

    def variant_name
      variant.name
    end

    def adjust_count_on_hand(value)
      self.with_lock do
        self.count_on_hand = self.count_on_hand + value
        process_backorders(count_on_hand - count_on_hand_was)

        self.save!
      end
    end

    def set_count_on_hand(value)
      self.count_on_hand = value
      process_backorders(count_on_hand - count_on_hand_was)

      self.save!
    end

    def in_stock?
      self.count_on_hand > 0
    end

    # Tells whether it's available to be included in a shipment
    def available?
      self.in_stock? || self.backorderable?
    end

    private
      def count_on_hand=(value)
        write_attribute(:count_on_hand, value)
      end

      # Process backorders based on amount of stock received
      # If stock was -20 and is now -15 (increase of 5 units), then we should process 5 inventory orders.
      # If stock was -20 but then was -25 (decrease of 5 units), do nothing.
      def process_backorders(number)
        if number > 0
          backordered_inventory_units.first(number).each do |unit|
            unit.fill_backorder
          end
        end
      end
  end
end
