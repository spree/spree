module Spree
  class PromotionRuleUser < Spree.base_class
    belongs_to :promotion_rule, class_name: 'Spree::PromotionRule'
    belongs_to :user, class_name: "::#{Spree.user_class}"

    validates :user, :promotion_rule, presence: true
    validates :user_id, uniqueness: { scope: :promotion_rule_id }, allow_nil: true
  end
end
