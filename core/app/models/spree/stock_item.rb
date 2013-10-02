module Spree
  class StockItem < ActiveRecord::Base
    acts_as_paranoid

    belongs_to :stock_location, class_name: 'Spree::StockLocation'
    belongs_to :variant, class_name: 'Spree::Variant'
    has_many :stock_movements

    validates_presence_of :stock_location, :variant
    validates_uniqueness_of :variant_id, scope: :stock_location_id
    validates :count_on_hand, :numericality => { :greater_than_or_equal_to => 0 }, :if => :verify_count_on_hand?

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
        process_backorders if in_stock?

        self.save!
      end
    end

    def set_count_on_hand(value)
      self.count_on_hand = value
      process_backorders if in_stock?

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
      def verify_count_on_hand?
        count_on_hand_changed? && !backorderable? && (count_on_hand < count_on_hand_was) && (count_on_hand < 0)
      end

      def count_on_hand=(value)
        write_attribute(:count_on_hand, value)
      end

      def process_backorders
        backordered_inventory_units.each do |unit|
          return unless in_stock?
          unit.fill_backorder
        end
      end
  end
end
