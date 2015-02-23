require_dependency 'spree/returns_calculator'

module Spree
  module Calculator::Returns
    class DefaultRefundAmount < ReturnsCalculator

      def self.description
        Spree.t(:default_refund_amount)
      end

      def compute(return_item)
        return 0.0.to_d if return_item.exchange_requested?
        adjustments = weighted_order_adjustment_amount(return_item.inventory_unit)
        line_item_pre_tax = weighted_line_item_pre_tax_amount(return_item.inventory_unit)
        adjustments + line_item_pre_tax
      end

      private

      def weighted_order_adjustment_amount(inventory_unit)
        adjustments = inventory_unit.order.adjustments.eligible.non_tax
        total_adjustments = adjustments.sum(:amount)
        total_adjustments -= adjustment_tax(inventory_unit.order, adjustments)
        total_adjustments * percentage_of_order_total(inventory_unit)
      end

      def adjustment_tax(order, adjustments)
        total = tax_affected_adjustments(adjustments).sum(&:amount)
        return 0.0 if total.zero?
        total * order.included_tax_total / order.item_total
      end

      def tax_affected_adjustments(adjustments)
        adjustments.to_a.keep_if { |a| a.source.tax_affected? }
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
