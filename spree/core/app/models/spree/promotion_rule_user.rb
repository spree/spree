module Spree
  class PromotionRuleUser < Spree.base_class
    belongs_to :promotion_rule, class_name: 'Spree::PromotionRule'
    belongs_to :customer, class_name: "::#{Spree.customer_class}"
    include Spree::DeprecatedCustomerAlias

    validates :user_id, uniqueness: { scope: :promotion_rule_id }, allow_nil: true
  end
end
