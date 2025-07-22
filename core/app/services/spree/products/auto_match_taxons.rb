module Spree
  module Products
    class AutoMatchTaxons
      prepend ::Spree::ServiceModule::Base

      def call(product:)
        return unless product.present?

        taxons_to_remove = []
        taxons_to_add = []

        # we need to check if existing taxons still match
        product.taxons.automatic.includes(:taxon_rules).each do |taxon|
          # products shouldn't be part of the taxon anymore
          # eg. product tags or category was changed
          taxons_to_remove << taxon unless taxon.products_matching_rules.ids.include?(product.id)
        end

        Spree::Classification.where(taxon: taxons_to_remove, product: product).delete_all if taxons_to_remove.any?

        # we need to check if product matches any existing taxons
        Spree::Taxon.automatic.includes(:taxon_rules, :products).each do |taxon|
          taxons_to_add << taxon if taxon.products.exclude?(product) && taxon.products_matching_rules.ids.include?(product.id)
        end

        if taxons_to_add.any?
          products_counts = Spree::Taxon.where(id: taxons_to_add.pluck(:id)).
                            joins(:classifications).
                            reorder('').
                            group(:taxon_id).
                            count(:product_id)

          Spree::Classification.insert_all(
            taxons_to_add.map do |taxon|
              position = products_counts[taxon.id].to_i + 1
              classification_attributes(taxon, product, position)
            end
          )
        end

        all_affected_taxons = (taxons_to_remove + taxons_to_add).uniq

        if all_affected_taxons.any?
          Spree::Taxons::TouchFeaturedSections.call(taxon_ids: all_affected_taxons.pluck(:id))
          product.touch
        end

        success(product)
      end

      private

      def classification_attributes(taxon, product, position)
        {
          taxon_id: taxon.id,
          product_id: product.id,
          position: position,
          created_at: Time.current,
          updated_at: Time.current
        }
      end
    end
  end
end
