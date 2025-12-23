module Spree
  class Promotion
    module Rules
      class User < PromotionRule
        #
        # Associations
        #
        has_many :promotion_rule_users, class_name: 'Spree::PromotionRuleUser',
                                        foreign_key: :promotion_rule_id,
                                        dependent: :destroy
        has_many :users, through: :promotion_rule_users, class_name: "::#{Spree.user_class}"

        #
        # Attributes
        #
        attr_accessor :user_ids_to_add

        #
        # Callbacks
        #
        after_save :add_users

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible_user_ids
          @eligible_user_ids ||= promotion_rule_users.pluck(:user_id)
        end

        def eligible?(order, _options = {})
          eligible_user_ids.include?(order.user_id)
        end

        def user_ids_string
          ActiveSupport::Deprecation.warn(
            'Spree::Promotion::Rules::User#user_ids_string is deprecated and will be removed in Spree 6.0. ' \
            'Please use `user_ids` instead.'
          )
          user_ids.join(',')
        end

        def user_ids_string=(s)
          ActiveSupport::Deprecation.warn(
            'Spree::Promotion::Rules::User#user_ids_string= is deprecated and will be removed in Spree 6.0. ' \
            'Please use `user_ids=` instead.'
          )
          self.user_ids = s
        end

        private

        def add_users
          return if user_ids_to_add.nil?

          promotion_rule_users.delete_all
          promotion_rule_users.insert_all(
            user_ids_to_add.map { |user_id| { user_id: user_id, promotion_rule_id: id } }
          )
        end
      end
    end
  end
end
