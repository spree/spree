module Spree
  module ProductTypes
    class ApplyToProductsJob < ::Spree::BaseJob
      queue_as Spree.queues.products

      def perform(product_type_id)
        product_type = Spree::ProductType.find_by(id: product_type_id)
        return if product_type.nil?

        Spree::ProductTypes::ApplyToProducts.call(product_type: product_type)
      end
    end
  end
end
