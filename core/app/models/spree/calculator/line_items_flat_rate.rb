require_dependency 'spree/calculator'

module Spree
  class Calculator::LineItemsFlatRate < Calculator
    preference :amount, :decimal, default: 0
    preference :currency, :string, default: -> { Spree::Config[:currency] }

    def self.description
      Spree.t(:fixed_amount_line_items)
    end

    def compute(object = nil)
      ams = object[:preferences][:actionable_amounts]
      actionable_line_items_total = object[:preferences][:actionable_total]
      last_actionable_line_item_id = object[:preferences][:last_actionable_line_item_id]

      # Ensure the line item meets the currency requirements
      return 0 unless object && preferred_currency.casecmp(object.currency.upcase).zero?

      if object.id != last_actionable_line_item_id || last_actionable_line_item_id.nil?

        # Use a proportional amout ot discount
        percentage_of_applicable = (object.amount / actionable_line_items_total)
        (preferred_amount * percentage_of_applicable).round(2)
      else

        # Use the remaining discount amount.
        discounts_used = []
        ams.each do |i|
          percentage_of_applicable = (i / actionable_line_items_total)
          discounts_used << (preferred_amount * percentage_of_applicable).round(2)
        end

        preferred_amount - discounts_used.inject(:+)
      end
    end
  end
end
