# Spree::OrderPromotion represents the relationship between:
# 1. A promotion that a user attempted to apply to their order
# 2. The specific code that they used
module Spree
  class OrderPromotion < Spree::Base
    belongs_to :order, class_name: 'Spree::Order'
    belongs_to :promotion, class_name: 'Spree::Promotion'
    belongs_to :promotion_code, class_name: 'Spree::PromotionCode'
  end
end
