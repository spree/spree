# Spree::StockMovement
# StockMovement is used for tracking stock item's total count_on_hand.
# An existing StockMovement udner a StockLocation can not be updated or destroyed.
#
module Spree
  class StockMovement < ActiveRecord::Base
    belongs_to :stock_item, class_name: 'Spree::StockItem'
    belongs_to :originator, polymorphic: true

    attr_accessible :quantity, :stock_item, :stock_item_id, :originator, :action

    after_create :update_stock_item_quantity

    validates :stock_item, presence: true
    validates :quantity, presence: true

    scope :recent, order('created_at DESC')

    # existing StockMovement is readonly as it should not be updated.
    def readonly?
      !new_record?
    end

    # existing StockMovement can not be destroy as it is used for 
    # tracking stock item's total count_on_hand.
    def destroy
      raise Spree.t(:can_not_destroy_stock_movement) if !new_record?
      super
    end

    private
    def update_stock_item_quantity
      return unless Spree::Config[:track_inventory_levels]
      stock_item.adjust_count_on_hand quantity
    end
  end
end

