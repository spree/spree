module Spree
  module Variants
    class RemoveLineItems
      prepend Spree::ServiceModule::Base

      def call(variant:)
        variant.line_items.joins(:order).where(spree_orders: { state: Spree::Order::LINE_ITEM_REMOVABLE_STATES }).find_each do |line_item|
          Spree::Variants::RemoveLineItemJob.perform_later(line_item: line_item)
        end

        success(true)
      end
    end
  end
end
