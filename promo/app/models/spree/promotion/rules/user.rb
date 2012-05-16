module Spree
  class Promotion
    module Rules
      class User < PromotionRule
        attr_accessible :user_ids_string

        belongs_to :user, :class_name => Spree.user_class.to_s
        has_and_belongs_to_many :users, :class_name => '::Spree::User', :join_table => 'spree_promotion_rules_users', :foreign_key => 'promotion_rule_id'

        def eligible?(order, options = {})
          users.none? or users.include?(order.user)
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
