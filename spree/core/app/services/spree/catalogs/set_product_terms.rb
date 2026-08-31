module Spree
  module Catalogs
    # Applies a catalog's per-product quantity terms as a set.
    #
    # Terms are stored per variant but stated per product, so a product's
    # pair is written to every one of its variants. A pair of blanks clears
    # that product's terms.
    #
    # Stating terms for a product outside the assortment **adds it**: a term
    # with nothing to apply to is not a state worth being able to reach, and
    # a merchant naming a minimum for a product plainly means to sell it
    # under this agreement (docs/plans/6.0-b2b-quantity-rules.md).
    class SetProductTerms
      prepend Spree::ServiceModule::Base

      # @param catalog [Spree::Catalog]
      # @param terms [Hash{Spree::Product => Hash}] :minimum_order_quantity,
      #   :order_multiple — either may be nil, meaning "defer to the catalog"
      # @return [Spree::ServiceModule::Result] value is the catalog
      def call(catalog:, terms:)
        return success(catalog) if terms.empty?

        foreign = terms.keys.reject { |product| product.store_id == catalog.store_id }
        return failure(catalog, Spree.t('catalogs.product_not_in_store')) if foreign.any?

        ApplicationRecord.transaction do
          catalog.add_products(terms.keys.reject { |product| catalog.product_ids.include?(product.id) }.map(&:id))

          terms.each { |product, values| apply(catalog, product, values) }
        end

        success(catalog.reload)
      end

      private

      def apply(catalog, product, values)
        minimum = normalize(values[:minimum_order_quantity])
        multiple = normalize(values[:order_multiple])
        variant_ids = product.variants.ids

        # Both blank is a deletion: the product falls back to the catalog's
        # own default, which is what an empty pair means on the row.
        if minimum.nil? && multiple.nil?
          catalog.quantity_rules.where(variant_id: variant_ids).destroy_all
          return
        end

        variant_ids.each do |variant_id|
          rule = catalog.quantity_rules.find_or_initialize_by(variant_id: variant_id)
          rule.assign_attributes(minimum_order_quantity: minimum, order_multiple: multiple)
          failure(rule) unless rule.save
        end
      end

      # A blank arrives as nil or an empty string depending on the client;
      # both mean "say nothing", which is not the same as zero.
      def normalize(value)
        return nil if value.nil? || value.to_s.strip.empty?

        value.to_i
      end
    end
  end
end
