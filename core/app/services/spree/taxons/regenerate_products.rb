module Spree
  module Taxons
    class RegenerateProducts
      prepend ::Spree::ServiceModule::Base

      def call(taxon:)
        return if taxon.nil?
        return if taxon.destroyed? || !Spree::Taxon.exists?(taxon.id)
        return if taxon.manual?

        previous_products_ids = taxon.classifications.order(position: :asc).pluck(:product_id)

        # https://api.rubyonrails.org/classes/ActiveRecord/Associations/CollectionProxy.html#method-i-delete_all
        # we don't want to run destroy_all here to avoid callbacks
        # default dependent value is nullify and that won't work for us
        taxon.classifications.delete_all(:delete_all)

        products_matching_rules = taxon.products_matching_rules
        product_ids_to_insert = products_matching_rules.ids

        previous_filtered_products_ids = previous_products_ids & product_ids_to_insert
        max_products_position = previous_filtered_products_ids.size || 0

        if product_ids_to_insert.any?
          records_to_insert = product_ids_to_insert.map do |product_id|
            position = previous_filtered_products_ids.index(product_id)
            position = position.present? ? position + 1 : max_products_position += 1

            classification_attributes(product_id, taxon, position)
          end

          Spree::Classification.insert_all(records_to_insert)

          # expire product cache
          Spree::Product.where(id: (previous_products_ids + product_ids_to_insert).uniq).touch_all
        end

        # update counter caches
        # Check if taxon still exists (may have been destroyed)
        Spree::Taxon.reset_counters(taxon.id, :classifications) if Spree::Taxon.exists?(taxon.id)
        all_product_ids = (previous_products_ids + product_ids_to_insert).uniq
        existing_product_ids = Spree::Product.where(id: all_product_ids).pluck(:id)
        existing_product_ids.each { |id| Spree::Product.reset_counters(id, :classifications) }

        success(taxon)
      end

      private

      def classification_attributes(product_id, taxon, position)
        {
          product_id: product_id,
          taxon_id: taxon.id,
          position: position,
          created_at: Time.current,
          updated_at: Time.current
        }
      end
    end
  end
end
