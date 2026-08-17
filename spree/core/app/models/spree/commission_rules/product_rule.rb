# frozen_string_literal: true

module Spree
  module CommissionRules
    # Charge this rate only for one of these products.
    #
    # Products hang off a join table rather than a preference array: a
    # marketplace naming a thousand products has a thousand rows, not a
    # thousand ids in a JSON column.
    class ProductRule < Spree::CommissionRule
      has_many :commission_rule_products, class_name: 'Spree::CommissionRuleProduct',
               foreign_key: :commission_rule_id, dependent: :destroy
      has_many :products, class_name: 'Spree::Product', through: :commission_rule_products

      def self.additional_permitted_attributes
        [product_ids: []]
      end

      # The chosen products in prefixed form, read through the association so
      # a soft-deleted product drops out — a client resubmitting this list must
      # not be told a product it never chose is unreachable. Sorted so a
      # response can be compared against what was sent.
      #
      # @return [Array<String>]
      def product_prefixed_ids
        products.pluck(:id).sort.map { |id| Spree::Product.prefixed_id_for(id) }
      end

      # Asked of the join table rather than by loading the whole list: a rate
      # covering much of the catalog would otherwise hydrate it per line item.
      def applicable?(context)
        return false if context.product.nil?

        commission_rule_products.exists?(product_id: context.product.id)
      end
    end
  end
end
