module Spree
  module Api
    module Webhooks
      module Payment
        def after_void
          super
          Spree::Webhooks::Endpoints::QueueRequests.call(event: 'payment.void', payload: {})
        end
      end
    end
  end
end
