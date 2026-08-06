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

      # Asks whether any of the package's products is excluded, rather than
      # loading the whole exclusion list — the join table's composite index
      # answers it without transferring rows. Unsaved rules can't be queried,
      # so those fall back to the in-memory association.
      def eligible?(package)
        product_ids = package.contents.map { |item| item.variant.product_id }.uniq
        return true if product_ids.empty?

        # `target` is whatever is already in memory — reading it never triggers
        # a load, so the persisted path stays a single indexed existence check.
        pending_links = delivery_method_rule_products.target.select(&:new_record?)
        return false if pending_links.any? { |link| product_ids.include?(link.product_id) }
        return true if new_record?

        !delivery_method_rule_products.exists?(product_id: product_ids)
      end
    end
  end
end
