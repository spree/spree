# A rule to limit a promotion based on order currency.
module Spree
  class Promotion
    module Rules
      class Currency < PromotionRule
        preference :currency, :string

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})
          return true if order.currency == preferred_currency

          eligibility_errors.add(:base, eligibility_error_message(:wrong_currency))
          false
        end
      end
    end
  end
end
