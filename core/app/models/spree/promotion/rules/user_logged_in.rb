module Spree
  class Promotion
    module Rules
      class UserLoggedIn < PromotionRule
        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, _options = {})
          unless order.user.present?
            # i18n-tasks-use I18n.t('spree.eligibility_errors.messages.no_user_specified')
            eligibility_errors.add(:base, eligibility_error_message(:no_user_specified))
          end
          eligibility_errors.empty?
        end
      end
    end
  end
end
