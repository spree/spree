module Spree
  module Api
    module V3
      class ProductCollectionSerializer < BaseSerializer
        typelize product_id: [:string, nullable: true],
                 collection_id: [:string, nullable: true]

        attribute :product_id do |product_collection|
          prefixed_id_for(Spree::Product, product_collection.product_id)
        end

        attribute :collection_id do |product_collection|
          prefixed_id_for(Spree::Collection, product_collection.collection_id)
        end

        private

        def prefixed_id_for(klass, id)
          return nil if id.nil?

          "#{klass._prefix_id_prefix}_#{Spree::PrefixedId::SQIDS.encode([id])}"
        end
      end
    end
  end
end
