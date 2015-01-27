# A rule to apply to an order greater than (or greater than or equal to)
# a specific quantity of line items
module Spree
  class Promotion
    module Rules
      class ItemQuantity < PromotionRule
        preference :quantity_min, :integer, default: 1
        preference :operator_min, :string, default: '>'
        preference :quantity_max, :integer, default: 1000
        preference :operator_max, :string, default: '<'

        OPERATORS_MIN = ['gt', 'gte']
        OPERATORS_MAX = ['lt', 'lte']

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})
          quantity = order.quantity

          lower_limit_condition = quantity.send(preferred_operator_min == 'gte' ? :>= : :>, preferred_quantity_min)
          upper_limit_condition = quantity.send(preferred_operator_max == 'lte' ? :<= : :<, preferred_quantity_max)

          eligibility_errors.add(:base, ineligible_message_max) unless upper_limit_condition
          eligibility_errors.add(:base, ineligible_message_min) unless lower_limit_condition

          eligibility_errors.empty?
        end

        private

        def ineligible_message_max
          if preferred_operator_max == 'gte'
            eligibility_error_message(:item_quantity_more_than_or_equal, quantity: preferred_quantity_max)
          else
            eligibility_error_message(:item_quantity_more_than, quantity: preferred_quantity_max)
          end
        end

        def ineligible_message_min
          if preferred_operator_min == 'gte'
            eligibility_error_message(:item_quantity_less_than, quantity: preferred_quantity_min)
          else
            eligibility_error_message(:item_quantity_less_than_or_equal, quantity: preferred_quantity_min)
          end
        end
      end
    end
  end
end
