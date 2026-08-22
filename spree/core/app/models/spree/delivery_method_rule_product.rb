module Spree
  class DeliveryMethodRuleProduct < Spree.base_class
    belongs_to :delivery_method_rule, class_name: 'Spree::DeliveryMethodRule'
    belongs_to :product, class_name: 'Spree::Product'

    validates :product_id, uniqueness: { scope: :delivery_method_rule_id }, allow_nil: true
  end
end
