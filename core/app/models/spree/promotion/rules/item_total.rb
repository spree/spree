# A rule to apply to an order greater than (or greater than or equal to)
# a specific amount
module Spree
  class Promotion
    module Rules
      class ItemTotal < PromotionRule
        preference :amount, :decimal, default: 100.00
        preference :operator, :string, default: '>'

        OPERATORS = ['gt', 'gte']

        def applicable?(promotable)
          promotable.is_a?(Spree::Order) || promotable.is_a?(Spree::Shipment)
        end

        def eligible?(promotable, options = {})
          if order.is_a?(Spree::Shipment)
            order = promotable.order
          else
            order = promotable
          end
          item_total = order.item_total
          item_total.send(preferred_operator == 'gte' ? :>= : :>, BigDecimal.new(preferred_amount.to_s))
        end
      end
    end
  end
end
