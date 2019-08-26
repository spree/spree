require_dependency 'spree/calculator'

module Spree
  module Calculator::Promotion
    class FlatRate < Calculator
      preference :amount, :decimal, default: 0
      preference :currency, :string, default: -> { Spree::Config[:currency] }

      def self.description
        Spree.t(:flat_rate)
      end

      def compute(object = nil, actionable_line_items_total = 0, last_actionable_line_item_id = nil, ams = nil)
        if object && preferred_currency.casecmp(object.currency.upcase).zero?
          if actionable_line_items_total == 0
            # If this is an Order Total type of Adjustment, then simply return the amount.
            preferred_amount
          else
            # If this is a Line Item type of Adjustment do the following to each line item.
            unless object.id == last_actionable_line_item_id || !last_actionable_line_item_id == nil
              # For most of the line items do the process below, and also if it is the only apllicable line item in the order.
              percentage_of_applicable = (object.amount / actionable_line_items_total)
              (preferred_amount * percentage_of_applicable).round(2)
            else
              # If there is more than one item in the order have the last applicable line item
              # eat the remainder of the discount, to pick up any rounding errors from the previous items calculations.
              # This ensures the adjustment total always matched the specified preffered_amount.
              discounts_used = []
              ams.each do |i|
                percentage_of_applicable = (i / actionable_line_items_total)
                discounts_used << (preferred_amount * percentage_of_applicable).round(2)
              end
              preferred_amount - discounts_used.inject(:+)
            end
          end
        else
          0
        end
      end
    end
  end
end
