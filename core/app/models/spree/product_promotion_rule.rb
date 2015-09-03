module Spree
  class ProductPromotionRule < Spree::Base
    belongs_to :product
    belongs_to :promotion_rule
  end
end
