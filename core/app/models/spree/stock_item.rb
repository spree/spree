module Spree
  class StockItem < ActiveRecord::Base
    belongs_to :stock_location
    belongs_to :variant
    has_many :stock_movements, dependent: :destroy

    validates_presence_of :stock_location, :variant
    validates_uniqueness_of :variant_id, scope: :stock_location_id

    attr_accessible :count_on_hand, :variant, :stock_location, :backorderable, :variant_id

    after_save :process_backorders
    delegate :weight, to: :variant

    def backordered_inventory_units
      Spree::InventoryUnit.backordered_for_stock_item(self)
    end

    def variant_name
      variant.name
    end

    def adjust_count_on_hand(value)
      self.with_lock do
        self.reload
        self.update_attribute(:count_on_hand, self.count_on_hand + value)
        self.save!
      end
    end

    def backordered_inventory_units
      Spree::InventoryUnit.backordered_for_stock_item(self)
    end

    private
      def process_backorders
        if count_changes = changes['count_on_hand']
          new_level = count_changes.last

          if Spree::Config[:track_inventory_levels] # && !self.on_demand
            new_level = new_level.to_i

            # update backorders if level is positive
            if new_level > 0
              # fill backordered orders before creating new units
              backordered_units = backordered_inventory_units
              # "lucky" because they're within the range of possibility to be filled
              # Inventory units are only "backfilled" up to the available product levels
              lucky_backordered_units = backordered_units.slice(0, new_level)

              lucky_backordered_units.each(&:fill_backorder)
              new_level -= lucky_backordered_units.length
            end

            self.update_column(:count_on_hand, new_level)
          end
        end
      end
  end
end
