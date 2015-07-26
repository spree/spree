module Spree
  class ProductPromotionRule < Spree::Base
    self.table_name = 'spree_products_promotion_rules'

    belongs_to :product, class_name: 'Spree::Product'
    belongs_to :promotion_rule, class_name: 'Spree::PromotionRule'
  end
end
