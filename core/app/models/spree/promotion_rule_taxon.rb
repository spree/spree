module Spree
  class PromotionRuleTaxon < Spree::Base
    belongs_to :promotion_rule, class_name: 'Spree::PromotionRule'
    belongs_to :taxon, class_name: 'Spree::Taxon'
  end
end
