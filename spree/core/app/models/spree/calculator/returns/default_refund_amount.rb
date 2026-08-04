require_dependency 'spree/returns_calculator'

module Spree
  module Calculator::Returns
    class DefaultRefundAmount < ReturnsCalculator
      attr_reader :fulfillment_item

      def self.description
        Spree.t(:default_refund_amount)
      end

      # The line item's pre_tax_amount already reflects every discount that
      # touches the line — including the line's share of whole-order
      # promotions, which are distributed to line-item Discount rows at
      # application time — so no separate order-level weighting is needed.
      def compute(return_item)
        return 0.0.to_d if return_item.exchange_requested?

        @fulfillment_item = return_item.fulfillment_item
        weighted_line_item_pre_tax_amount(return_item)
      end

      private

      def weighted_line_item_pre_tax_amount(return_item)
        fulfillment_item.line_item.pre_tax_amount * percentage_of_line_item(return_item)
      end

      def percentage_of_line_item(return_item)
        return_item.return_quantity / BigDecimal(fulfillment_item.line_item.quantity)
      end
    end
  end
end
