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

      def self.additional_permitted_attributes
        [product_ids: []]
      end

      # Excluded product ids in prefixed form, encoded from the join table's
      # foreign keys — hydrating N Product rows just to re-encode their ids
      # would be wasted I/O. Sorted so clients can compare a response against
      # what they sent.
      #
      # @return [Array<String>]
      def product_prefixed_ids
        delivery_method_rule_products.pluck(:product_id).sort.map do |id|
          Spree::Product.prefixed_id_for(id)
        end
      end

      # Asks whether any of the package's products is excluded, rather than
      # loading the whole exclusion list — the join table's composite index
      # answers it without transferring rows.
      def eligible?(package)
        product_ids = package.contents.map { |item| item.variant.product_id }.uniq
        return true if product_ids.empty?

        # `target` is whatever is already in memory, so reading it never
        # triggers a load. It covers links assigned but not yet saved — the
        # admin controller assigns products before saving the rule.
        return false if delivery_method_rule_products.target.any? { |link|
          link.new_record? && product_ids.include?(link.product_id)
        }
        # An unsaved rule has no rows to query, and asking would still cost a
        # round trip.
        return true if new_record?

        !delivery_method_rule_products.exists?(product_id: product_ids)
      end
    end
  end
end
