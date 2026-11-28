# A rule to apply to an order greater than (or greater than or equal to)
# a specific amount. Free gifts and products the promotion excludes do not
# count toward it.
module Spree
  class Promotion
    module Rules
      class ItemTotal < Spree::PromotionRule
        preference :amount_min, :money, default: 100.00
        preference :operator_min, :string, default: '>'
        preference :amount_max, :money, default: nil, nullable: true
        preference :operator_max, :string, default: '<'

        OPERATORS_MIN = ['gt', 'gte']
        OPERATORS_MAX = ['lt', 'lte']

        def eligible?(order, options = {})
          item_total = counted_total(order, options)

          lower_limit_condition = item_total.send(preferred_operator_min == 'gte' ? :>= : :>, BigDecimal(preferred_amount_min.to_s))

          if preferred_amount_max.present?
            upper_limit_condition = item_total.send(preferred_operator_max == 'lte' ? :<= : :<, BigDecimal(preferred_amount_max.to_s))
          else
            upper_limit_condition = true
          end

          eligibility_errors.add(:base, ineligible_message_max(order)) unless upper_limit_condition
          eligibility_errors.add(:base, ineligible_message_min(order)) unless lower_limit_condition

          eligibility_errors.empty?
        end

        private

        def counted_total(order, options)
          gift_options = { promotion: promotion, own_gift_only: options.fetch(:own_gift_only, false) }
          total = order.item_total - order.gift_amount(**gift_options)
          excluded = promotion ? order.line_items.select { |line_item| promotion.excludes_line_item?(line_item) } : []
          return total if excluded.empty?

          # Gift units on the excluded lines are already out of the total.
          total - excluded.sum(BigDecimal(0), &:amount) + order.gift_amount(**gift_options, among: excluded)
        end

        def formatted_amount_min(order)
          Spree::Money.new(preferred_amount_min, currency: order.currency).to_s
        end

        def formatted_amount_max(order)
          if preferred_amount_max.present?
            Spree::Money.new(preferred_amount_max, currency: order.currency).to_s
          else
            I18n.t('spree.no_maximum')
          end
        end

        def ineligible_message_max(order)
          if preferred_operator_max == 'lt'
            eligibility_error_message(:item_total_more_than_or_equal, amount: formatted_amount_max(order))
          else
            eligibility_error_message(:item_total_more_than, amount: formatted_amount_max(order))
          end
        end

        def ineligible_message_min(order)
          if preferred_operator_min == 'gte'
            eligibility_error_message(:item_total_less_than, amount: formatted_amount_min(order))
          else
            eligibility_error_message(:item_total_less_than_or_equal, amount: formatted_amount_min(order))
          end
        end
      end
    end
  end
end
