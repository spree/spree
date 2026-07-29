module Spree
  module Variants
    class RemoveLineItems
      prepend Spree::ServiceModule::Base

      def call(variant:)
        # Removable = still mutable: any cart-owned line, or a line on an
        # uncompleted, uncanceled order (drafts).
        variant.line_items.where.not(cart_id: nil).find_each do |line_item|
          Spree::Variants::RemoveLineItemJob.perform_later(line_item: line_item)
        end
        variant.line_items.joins(:order).merge(Spree::Order.incomplete.not_canceled).find_each do |line_item|
          Spree::Variants::RemoveLineItemJob.perform_later(line_item: line_item)
        end

        success(true)
      end
    end
  end
end
