module Spree
  class PromotionActionLineItem < Spree.base_class
    belongs_to :promotion_action, class_name: 'Spree::Promotion::Actions::CreateLineItems'
    belongs_to :variant, class_name: 'Spree::Variant'

    validates :quantity, presence: true
    validates :quantity, numericality: { only_integer: true, message: I18n.t('spree.validation.must_be_int') }
  end
end
