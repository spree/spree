module Spree
  class StockItem < ActiveRecord::Base
    belongs_to :stock_location
    belongs_to :variant
    has_many :stock_movements, dependent: :destroy

    validates_presence_of :stock_location
    validates_uniqueness_of :variant_id, :scope => :stock_location_id

    attr_accessible :count_on_hand, :variant, :stock_location, :backorderable, :variant_id

    after_save :process_backorders

    delegate :weight, :to => :variant

    def backordered_inventory_units
      Spree::InventoryUnit.backordered_for_stock_item(self)
    end

    def variant_name
      variant.name
    end

    def determine_backorder(quantity)
      return 0 unless Spree::Config[:track_inventory_levels]

      if count_on_hand == 0
        quantity
      elsif count_on_hand < quantity
        quantity - (count_on_hand < 0 ? 0 : count_on_hand)
      else
        0
      end
    end

    private
    def process_backorders
      if count_changes = changes['count_on_hand']
        new_level = count_changes.last
        new_level = new_level.to_i

        if new_level > 0
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
