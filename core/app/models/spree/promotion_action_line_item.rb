module Spree
  class PromotionActionLineItem < Spree::Base
    belongs_to :promotion_action, class_name: 'Spree::Promotion::Actions::CreateLineItems'
    belongs_to :variant, class_name: 'Spree::Variant'

    validates :promotion_action, :variant, :quantity, presence: true
    validates :quantity, numericality: { only_integer: true, message: Spree.t('validation.must_be_int') }
  end
end
