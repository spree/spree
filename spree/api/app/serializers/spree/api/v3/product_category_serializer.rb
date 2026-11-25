module Spree
  module Api
    module V3
      class ProductCategorySerializer < BaseSerializer
        typelize product_id: [:string, nullable: true],
                 category_id: [:string, nullable: true]

        attribute :product_id do |product_category|
          Spree::Product.prefixed_id_for(product_category.product_id)
        end

        attribute :category_id do |product_category|
          Spree::Category.prefixed_id_for(product_category.category_id)
        end
      end
    end
  end
end
