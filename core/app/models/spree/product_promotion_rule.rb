module Spree
  class ProductPromotionRule < Spree::Base
    belongs_to :product, class_name: 'Spree::Product'
    belongs_to :promotion_rule, class_name: 'Spree::PromotionRule'

    validates :product, :promotion_rule, presence: true
    validates :product_id, uniqueness: { scope: :promotion_rule_id }, allow_nil: true
  end
end
