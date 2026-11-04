module Spree
  module Api
    module V3
      class ProductCategorySerializer < BaseSerializer
        typelize product_id: [:string, nullable: true],
                 category_id: [:string, nullable: true]

        prefixed_id_attributes :product, :category
      end
    end
  end
end
