module Spree
  class Promotion
    module Rules
      class User < PromotionRule
        if Spree.user_class
          belongs_to :user, class_name: Spree.user_class.to_s
          has_and_belongs_to_many :users, class_name: Spree.user_class.to_s, join_table: 'spree_promotion_rules_users', foreign_key: 'promotion_rule_id'
        else
          belongs_to :user
          has_and_belongs_to_many :users, join_table: 'spree_promotion_rules_users', foreign_key: 'promotion_rule_id', :class_name => Spree.user_class
        end

        def eligible?(order, options = {})
          users.include?(order.user)
        end

        def user_ids_string
          user_ids.join(',')
        end

        def user_ids_string=(s)
          self.user_ids = s.to_s.split(',').map(&:strip)
        end
      end
    end
  end
end
