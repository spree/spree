module Spree
  module Products
    # Puts a product on sale. Replaces the `activate` state machine event: the
    # write and the event it publishes live here rather than in an
    # after_transition, so a handler can veto the change before anything is
    # written and see the product it applies to.
    class Activate < Spree::Workflow
      hooks :validate, :after_activate

      # @param product [Spree::Product]
      # @return [Spree::ServiceModule::Result] value is the product
      def perform(product:)
        super

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_active
          run_hooks :after_activate
        end

        product.publish_event('product.activated')
        success(product)
      end

      private

      def mark_active
        failure(product) unless product.update(status: 'active')
      end
    end
  end
end
