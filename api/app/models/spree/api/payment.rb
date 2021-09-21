module Spree
  module Api
    module Payment
      private

      def after_void
        super
        Spree::Webhooks::Endpoints::QueueRequests.call(event: 'payment.void', payload: {})
      end
    end
  end
end
