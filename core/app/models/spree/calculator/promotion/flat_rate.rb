require_dependency 'spree/calculator'

module Spree
  module Calculator::Promotion
    class FlatRate < Calculator
      preference :amount, :decimal, default: 0
      preference :currency, :string, default: -> { Spree::Config[:currency] }

      def self.description
        Spree.t(:flat_rate)
      end

      def compute(object = nil, actionable_line_items_total = 0, last_actionable_line_item_id, ams)
        if object && preferred_currency.casecmp(object.currency.upcase).zero?
          if actionable_line_items_total == 0
          # If this is an Order Total type of Adjustment do this
            preferred_amount
          else
          # If this is a Line Item Adjustment do this
            unless object.id == last_actionable_line_item_id || !last_actionable_line_item_id == nil
              # For most of the line items do this and also
              # do this if its the only apllicable item in cart
              percentage_of_applicable = BigDecimal((object.amount / actionable_line_items_total).to_s)
              computed_amount = (BigDecimal(preferred_amount.to_s) * percentage_of_applicable).round(2)
            else
              # If there is more than one item in cart
              # Get the last item to eat the remainder of the discount, even if
              # the rounding makes it a penny over or under
              discounts_used = []
              ams.each do |i|
                percentage_of_applicable = BigDecimal((i / actionable_line_items_total).to_s)
                discounts_used << (BigDecimal(preferred_amount.to_s) * percentage_of_applicable).round(2)
              end
              computed_amount = (preferred_amount - discounts_used.inject(:+))
            end
          end
        else
          0
        end
      end
    end
  end
end
