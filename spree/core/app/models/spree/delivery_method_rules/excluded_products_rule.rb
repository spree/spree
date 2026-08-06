module Spree
  module DeliveryMethodRules
    # Blocks the method for packages containing any of the attached products
    # ("fragile item can't ship express"). Products hang off the concrete
    # spree_delivery_method_rule_products join table — catalog-scale
    # references never live in preferences. A rule with no products passes,
    # matching the empty-preference fail-open convention.
    class ExcludedProductsRule < Spree::DeliveryMethodRule
      has_many :delivery_method_rule_products, class_name: 'Spree::DeliveryMethodRuleProduct',
               foreign_key: :delivery_method_rule_id, dependent: :destroy,
               inverse_of: :delivery_method_rule
      has_many :products, class_name: 'Spree::Product', through: :delivery_method_rule_products

      def eligible?(package)
        excluded_ids = delivery_method_rule_products.pluck(:product_id)
        return true if excluded_ids.empty?

        package.contents.none? { |item| excluded_ids.include?(item.variant.product_id) }
      end
    end
  end
end
