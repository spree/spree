module Spree
  class PromotionRuleTaxon < Spree::Base
    self.table_name = 'spree_taxons_promotion_rules'

    belongs_to :promotion_rule, class_name: 'Spree::PromotionRule'
    belongs_to :taxons, class_name: 'Spree::Taxon'
  end
end
