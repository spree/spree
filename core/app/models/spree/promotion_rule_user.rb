module Spree
  class PromotionRuleUser < Spree::Base
    belongs_to :promotion_rule, class_name: 'Spree::PromotionRule'
    belongs_to :user, class_name: Spree.user_class
  end
end
