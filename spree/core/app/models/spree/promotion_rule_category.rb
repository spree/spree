module Spree
  # Join model between a Spree::Promotion::Rules::Category rule and a
  # Spree::Category. Renamed from Spree::PromotionRuleTaxon in 6.0 (alias kept for
  # one release).
  class PromotionRuleCategory < Spree.base_class
    belongs_to :promotion_rule, class_name: 'Spree::PromotionRule'
    belongs_to :category, class_name: 'Spree::Category'

    validates :promotion_rule, :category, presence: true
    validates :promotion_rule_id, uniqueness: { scope: :category_id }, allow_nil: true

    # @deprecated Use #category / #category=; removed in 6.1.
    def taxon
      category
    end

    def taxon=(value)
      self.category = value
    end
  end
end
