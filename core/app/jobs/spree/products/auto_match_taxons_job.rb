module Spree
  module Products
    class AutoMatchTaxonsJob < ::Spree::BaseJob
      queue_as Spree.queues.taxons

      def perform(product_id)
        product = Spree::Product.find_by(id: product_id)
        return unless product.present?

        Spree::Products::AutoMatchTaxons.call(product: product)
      end
    end
  end
end
