require_dependency 'spree/returns_calculator'

module Spree
  module Calculator::Returns
    class DefaultRefundAmount < ReturnsCalculator
      attr_reader :inventory_unit

      def self.description
        Spree.t(:default_refund_amount)
      end

      def compute(return_item)
        return 0.0.to_d if return_item.exchange_requested?

        @inventory_unit = return_item.inventory_unit
        # pre_tax_amount is net of ALL discounts — item-level and the
        # distributed share of whole-order promotions — so adding a separate
        # weighted order-adjustment share would double-count them
        weighted_line_item_pre_tax_amount(return_item)
      end

      private

      def weighted_line_item_pre_tax_amount(return_item)
        inventory_unit.line_item.pre_tax_amount * percentage_of_line_item(return_item)
      end

      def percentage_of_line_item(return_item)
        return_item.return_quantity / BigDecimal(inventory_unit.line_item.quantity)
      end
    end
  end
end
