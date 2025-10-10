module Spree
  module Variants
    class RemoveFromIncompleteOrdersJob < Spree::BaseJob
      queue_as Spree.queues.variants

      def perform(variant)
        Spree::Variants::RemoveLineItems.call(variant: variant)
      end
    end
  end
end
