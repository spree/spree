module Spree
  class Promotion
    module Rules
      class User < Spree::PromotionRule
        #
        # Associations
        #
        has_many :promotion_rule_users, class_name: 'Spree::PromotionRuleUser',
                                        foreign_key: :promotion_rule_id,
                                        dependent: :destroy
        has_many :users, through: :promotion_rule_users, source: :customer, class_name: "::#{Spree.customer_class}"

        # Customers, not admin users — the rule keys off `Spree::Order#customer_id`.
        # The data layer keeps the `users` association name (deferred model rename);
        # the API exposes the same set as `customer_ids`.
        self.additional_permitted_attributes = [customer_ids: []]

        # Wire-format shorthand is `customer` (the model is still `User`
        # pre-6.0 rename, see docs/plans/6.0-platform-auth.md).
        def self.api_type
          'customer'
        end

        def customer_ids
          user_ids
        end

        def customer_ids=(ids)
          self.user_ids = ids
        end

        #
        # Attributes
        #
        attr_accessor :user_ids_to_add

        #
        # Callbacks
        #
        after_save :add_users

        def applicable?(promotable)
          promotable.is_a?(Spree::Order) || promotable.is_a?(Spree::Cart)
        end

        def eligible_user_ids
          @eligible_user_ids ||= promotion_rule_users.pluck(:customer_id)
        end

        def eligible?(order, _options = {})
          eligible_user_ids.include?(order.customer_id)
        end

        def user_ids_string
          ActiveSupport::Deprecation.warn(
            'Spree::Promotion::Rules::User#user_ids_string is deprecated and will be removed in Spree 5.5. ' \
            'Please use `user_ids` instead.'
          )
          user_ids.join(',')
        end

        def user_ids_string=(s)
          ActiveSupport::Deprecation.warn(
            'Spree::Promotion::Rules::User#user_ids_string= is deprecated and will be removed in Spree 5.5. ' \
            'Please use `user_ids=` instead.'
          )
          self.user_ids = s
        end

        private

        def add_users
          return if user_ids_to_add.nil?

          promotion_rule_users.delete_all

          if user_ids_to_add.any?
            Spree::PromotionRuleUser.insert_all(
              user_ids_to_add.map { |customer_id| { customer_id: customer_id, promotion_rule_id: id } }
            )
          end

          # Invalidate cache after bulk operations
          touch

          # Clear memoized values
          @eligible_user_ids = nil
        end
      end
    end
  end
end
