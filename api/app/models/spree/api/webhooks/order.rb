module Spree
  module Api
    module Webhooks
      module Order
        def after_cancel
          super
          Spree::Webhooks::Endpoints::QueueRequests.call(event: 'order.cancel', payload: {})
        end

        def finalize!
          super
          Spree::Webhooks::Endpoints::QueueRequests.call(event: 'order.complete', payload: {})
        end
      end
    end
  end
end
