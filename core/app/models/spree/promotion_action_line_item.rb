module Spree
  class PromotionActionLineItem < Spree::Base
    belongs_to :promotion_action, class_name: 'Spree::Promotion::Actions::CreateLineItems'
    belongs_to :variant, class_name: 'Spree::Variant'
  end
end
