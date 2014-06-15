module Spree
  module Returns
    class LineItemReturn
      attr_reader :line_item, :quantity
      delegate :order, to: :line_item

      def initialize(line_item, quantity)
        line_item.is_a?(Spree::LineItem) ? @line_item = line_item : raise("Line Item Required")
        quantity.is_a?(Integer) ? @quantity = quantity : raise("Quantity Required")
      end

      # TODO a method that actually executes the return of a line item
      # verify that amount_to_return for non-returned line items doesn't change
      # def return
      #   # choose and do correct type of refund, store with association to line item
      #   line_item.update_attributes(returned_amount: amount_to_return)
      # end

      def amount_to_return
        (amount_of_order_adjustment + pre_tax_amount + tax_amount).round(2)
      end

      private

      def pre_tax_amount
        line_item.pre_tax_amount * percentage_of_line_item
      end

      def tax_amount
        line_item.total_taxes * percentage_of_line_item
      end

      def amount_of_order_adjustment
        order.adjustment_total * percentage_of_order
      end

      def percentage_of_order
        return 0.0 if order.pre_tax_item_amount.zero?
        pre_tax_amount / order.pre_tax_item_amount
      end

      def percentage_of_line_item
        BigDecimal.new(quantity) / BigDecimal.new(line_item.quantity)
      end
    end
  end
end
