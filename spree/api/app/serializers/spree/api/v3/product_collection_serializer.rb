module Spree
  module Api
    module V3
      class ProductCollectionSerializer < BaseSerializer
        typelize product_id: [:string, nullable: true],
                 collection_id: [:string, nullable: true]

        attribute :product_id do |product_collection|
          Spree::Product.prefixed_id_for(product_collection.product_id)
        end

        attribute :collection_id do |product_collection|
          Spree::Collection.prefixed_id_for(product_collection.collection_id)
        end
      end
    end
  end
end
