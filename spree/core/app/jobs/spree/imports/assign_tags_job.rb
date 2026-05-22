module Spree
  module Imports
    class AssignTagsJob < Spree::BaseJob
      queue_as Spree.queues.imports

      # Narrowed to transient infrastructure errors. RecordNotFound (deleted product)
      # and RecordInvalid (validation failure) won't recover from retry — they belong
      # in error reporting, not the retry queue.
      retry_on ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout,
               ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed,
               wait: :polynomially_longer, attempts: 5
      discard_on ActiveRecord::RecordNotFound, ActiveJob::DeserializationError

      def perform(product_id, tags)
        product = Spree::Product.find(product_id)
        product.tag_list = tags
        product.save!
      end
    end
  end
end
