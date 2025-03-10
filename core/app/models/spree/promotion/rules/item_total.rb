# A rule to apply to an order greater than (or greater than or equal to)
# a specific amount
module Spree
  class Promotion
    module Rules
      class ItemTotal < PromotionRule
        preference :amount_min, :decimal, default: 100.00
        preference :operator_min, :string, default: '>'
        preference :amount_max, :decimal, default: nil, nullable: true
        preference :operator_max, :string, default: '<'

        OPERATORS_MIN = ['gt', 'gte']
        OPERATORS_MAX = ['lt', 'lte']

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, _options = {})
          item_total = order.item_total

          lower_limit_condition = item_total.send(preferred_operator_min == 'gte' ? :>= : :>, BigDecimal(preferred_amount_min.to_s))

          if preferred_amount_max.present?
            upper_limit_condition = item_total.send(preferred_operator_max == 'lte' ? :<= : :<, BigDecimal(preferred_amount_max.to_s))
          else
            upper_limit_condition = true
          end

          eligibility_errors.add(:base, ineligible_message_max) unless upper_limit_condition
          eligibility_errors.add(:base, ineligible_message_min) unless lower_limit_condition

          eligibility_errors.empty?
        end

        private

        def formatted_amount_min
          Spree::Money.new(preferred_amount_min).to_s
        end

        def formatted_amount_max
          if preferred_amount_max.present?
            Spree::Money.new(preferred_amount_max).to_s
          else
            Spree.t('no_maximum')
          end
        end

        def ineligible_message_max
          if preferred_operator_max == 'lt'
            eligibility_error_message(:item_total_more_than_or_equal, amount: formatted_amount_max)
          else
            eligibility_error_message(:item_total_more_than, amount: formatted_amount_max)
          end
        end

        def ineligible_message_min
          if preferred_operator_min == 'gte'
            eligibility_error_message(:item_total_less_than, amount: formatted_amount_min)
          else
            eligibility_error_message(:item_total_less_than_or_equal, amount: formatted_amount_min)
          end
        end
      end
    end
  end
end
