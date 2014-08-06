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
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})
          item_total = order.item_total
          unless item_total.send(preferred_operator == 'gte' ? :>= : :>, BigDecimal.new(preferred_amount.to_s))
            eligibility_errors.add(:base, ineligible_message)
          end

          eligibility_errors.empty?
        end

        private
        def formatted_amount
          Spree::Money.new(preferred_amount).to_s
        end

        def ineligible_message
          if preferred_operator == 'gte'
            eligibility_error_message(:item_total_less_than, amount: formatted_amount)
          else
            eligibility_error_message(:item_total_less_than_or_equal, amount: formatted_amount)
          end
        end
      end
    end
  end
end
