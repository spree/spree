require_dependency 'spree/returns_calculator'

module Spree
  module Calculator::Returns
    class DefaultRefundAmount < ReturnsCalculator

      def self.description
        Spree.t(:default_refund_amount)
      end

      def compute(return_item)
        return 0.0.to_d if return_item.exchange_requested?
        weighted_order_adjustment_amount(return_item.inventory_unit) + weighted_line_item_pre_tax_amount(return_item.inventory_unit)
      end

      private

      def weighted_order_adjustment_amount(inventory_unit)
        inventory_unit.order.adjustments.eligible.non_tax.sum(:amount) * percentage_of_order_total(inventory_unit)
      end

      def weighted_line_item_pre_tax_amount(inventory_unit)
        inventory_unit.line_item.pre_tax_amount * percentage_of_line_item(inventory_unit)
      end

      def percentage_of_order_total(inventory_unit)
       return 0.0 if inventory_unit.order.pre_tax_item_amount.zero?
       weighted_line_item_pre_tax_amount(inventory_unit) / inventory_unit.order.pre_tax_item_amount
     end

     def percentage_of_line_item(inventory_unit)
       1 / BigDecimal.new(inventory_unit.line_item.quantity)
     end
   end
 end
end
