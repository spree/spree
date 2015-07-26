module Spree
  class PromotionRuleTaxon < Spree::Base
    self.table_name = 'spree_promotion_rules_taxons'

    belongs_to :promotion_rule, class_name: 'Spree::PromotionRule'
    belongs_to :taxons, class_name: 'Spree::Taxon'
  end
end
