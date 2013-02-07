# A rule to apply to an order greater than (or greater than or equal to)
# a specific amount
module Spree
  class Promotion
    module Rules
      class ItemTotal < PromotionRule
        preference :amount, :decimal, default: 100.00
        preference :operator, :string, default: '>'

        OPERATORS = ['gt', 'gte']

        def eligible?(order, options = {})
          item_total = order.line_items.map(&:amount).sum
          item_total.send(preferred_operator == 'gte' ? :>= : :>, BigDecimal.new(preferred_amount.to_s))
        end
      end
    end
  end
end
