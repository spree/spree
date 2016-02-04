module Spree
  class PromotionRuleTaxon < Spree::Base
    belongs_to :promotion_rule, class_name: 'Spree::PromotionRule'
    belongs_to :taxon, class_name: 'Spree::Taxon'

    validates :promotion_rule, :taxon, presence: true
    validates :promotion_rule_id, uniqueness: { scope: :taxon_id }, allow_nil: true
  end
end
