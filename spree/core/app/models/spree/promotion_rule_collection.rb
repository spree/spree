module Spree
  # Join model between a Spree::Promotion::Rules::Collection rule and a Spree::Collection.
  class PromotionRuleCollection < Spree.base_class
    belongs_to :promotion_rule, class_name: 'Spree::PromotionRule'
    belongs_to :collection, class_name: 'Spree::Collection'

    validates :collection_id, uniqueness: { scope: :promotion_rule_id }
  end
end
