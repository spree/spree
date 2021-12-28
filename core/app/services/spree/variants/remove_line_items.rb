module Spree
  module Variants
    class RemoveLineItems
      prepend Spree::ServiceModule::Base

      def call(variant:)
        variant.line_items.joins(:order).where.not(spree_orders: { state: 'complete' }).find_each do |line_item|
          Spree::Variants::RemoveLineItemJob.perform_later(line_item: line_item)
        end

        success(true)
      end
    end
  end
end
