module Spree
  module Imports
    class AssignTagsJob < Spree::BaseJob
      queue_as Spree.queues.imports
      retry_on StandardError, wait: :polynomially_longer, attempts: 5

      def perform(product_id, tags)
        product = Spree::Product.find(product_id)
        product.tag_list = tags
        product.save!
      end
    end
  end
end
