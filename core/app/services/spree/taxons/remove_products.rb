module Spree
  module Taxons
    class RemoveProducts
      prepend Spree::ServiceModule::Base

      # Removes the given products from the given taxons.
      #
      # @param taxons [Array<Spree::Taxon>]
      # @param products [Array<Spree::Product>]
      # @return [Spree::ServiceModule::Base::Result]
      def call(taxons:, products:)
        return if taxons.blank? || products.blank?

        taxon_ids = taxons.pluck(:id)
        product_ids = products.pluck(:id)

        ApplicationRecord.transaction do
          taxon_ids.each do |taxon_id|
            Spree::Classification.where(taxon_id: taxon_id, product_id: product_ids).delete_all
          end

          classifications_params = taxon_ids.flat_map do |taxon_id|
            position = 0
            existing_product_ids = Spree::Classification.where(taxon_id: taxon_id).pluck(:product_id)

            existing_product_ids.map do |product_id|
              {
                taxon_id: taxon_id,
                product_id: product_id,
                position: (position += 1),
                created_at: Time.current,
                updated_at: Time.current
              }
            end
          end

          if classifications_params.any?
            opts = {}
            opts[:unique_by] = :index_spree_products_taxons_on_product_id_and_taxon_id unless ActiveRecord::Base.connection.adapter_name == 'Mysql2'

            Spree::Classification.upsert_all(
              classifications_params,
              **opts
            )
          end
        end

        # update counter caches
        taxon_ids.each { |id| Spree::Taxon.reset_counters(id, :classifications) }
        product_ids.each { |id| Spree::Product.reset_counters(id, :classifications) }

        # clear cache
        Spree::Product.where(id: product_ids).touch_all
        Spree::Taxon.where(id: taxon_ids).touch_all
        Spree::Taxons::TouchFeaturedSections.call(taxon_ids: taxon_ids) if defined?(Spree::Taxons::TouchFeaturedSections)

        success(true)
      end
    end
  end
end
