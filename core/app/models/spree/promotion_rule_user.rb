module Spree
  class PromotionRuleUser < Spree::Base
    belongs_to :promotion_rule, class_name: 'Spree::PromotionRule'
    belongs_to :user, class_name: Spree.user_class

    validates :promotion_rule, :user, presence: true
    validates :promotion_rule_id, uniqueness: { scope: :user_id }, allow_nil: true
  end
end
