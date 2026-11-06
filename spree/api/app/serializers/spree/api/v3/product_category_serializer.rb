module Spree
  module Api
    module V3
      class ProductCategorySerializer < BaseSerializer
        typelize product_id: [:string, nullable: true],
                 category_id: [:string, nullable: true]

        attribute :product_id do |product_category|
          prefixed_id_for(Spree::Product, product_category.product_id)
        end

        attribute :category_id do |product_category|
          prefixed_id_for(Spree::Category, product_category.category_id)
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
