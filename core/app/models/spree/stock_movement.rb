module Spree
  class StockMovement < ActiveRecord::Base
    belongs_to :stock_item, class_name: 'Spree::StockItem'
    belongs_to :originator, polymorphic: true

    after_create :update_stock_item_quantity

    validates :stock_item, presence: true
    validates :quantity, presence: true

    scope :recent, -> { order('created_at DESC') }

    def readonly?
      !new_record?
    end

    private
    def update_stock_item_quantity
      return unless Spree::Config[:track_inventory_levels]
      stock_item.adjust_count_on_hand quantity
    end
  end
end

