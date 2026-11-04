module Spree
  module Api
    module V3
      class ProductCollectionSerializer < BaseSerializer
        typelize product_id: [:string, nullable: true],
                 collection_id: [:string, nullable: true]

        prefixed_id_attributes :product, :collection
      end
    end
  end
end
