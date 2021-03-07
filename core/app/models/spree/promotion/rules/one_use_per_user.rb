module Spree
  class Promotion
    module Rules
      class OneUsePerUser < PromotionRule
        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, _options = {})
          if order.user.present?
            if promotion.used_by?(order.user, [order])
              # i18n-tasks-use I18n.t('spree.eligibility_errors.messages.limit_once_per_user')
              eligibility_errors.add(:base, eligibility_error_message(:limit_once_per_user))
            end
          else
            # i18n-tasks-use I18n.t('spree.eligibility_errors.messages.no_user_specified')
            eligibility_errors.add(:base, eligibility_error_message(:no_user_specified))
          end

          eligibility_errors.empty?
        end
      end
    end
  end
end
