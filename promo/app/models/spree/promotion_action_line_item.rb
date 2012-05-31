module Spree
  class PromotionActionLineItem < ActiveRecord::Base
    belongs_to :promotion_action, :class_name => 'Spree::Promotion::Actions::CreateLineItems'
    belongs_to :variant, :class_name => "Spree::Variant"
  end
end
