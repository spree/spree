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
          @eligibility_errors = ActiveModel::Errors.new(self)

          item_total = order.item_total
          unless item_total.send(preferred_operator == 'gte' ? :>= : :>, BigDecimal.new(preferred_amount.to_s))
            amount = Spree::Money.new(preferred_amount).to_s
            message = if preferred_operator == 'gte'
                        eligibility_error_message(:item_total_less_than, amount: amount)
                      else
                        eligibility_error_message(:item_total_less_than_or_equal, amount: amount)
                      end
            @eligibility_errors.add(:base, message)
          end

          @eligibility_errors.empty?
        end
      end
    end
  end
end
