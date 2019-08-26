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
            preferred_amount
          elsif object.id == last_actionable_line_item_id && !last_actionable_line_item_id.nil?
            discounts_used = []
            ams.each do |i|
              percentage_of_applicable = (i / actionable_line_items_total)
              discounts_used << (preferred_amount * percentage_of_applicable).round(2)
            end
            preferred_amount - discounts_used.inject(:+)
          else
            percentage_of_applicable = (object.amount / actionable_line_items_total)
            (preferred_amount * percentage_of_applicable).round(2)
          end
        else
          0
        end
      end
    end
  end
end
