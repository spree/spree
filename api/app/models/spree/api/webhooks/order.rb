module Spree
  module Api
    module Webhooks
      module Order
        def after_cancel
          super
          queue_webhooks_requests!('order.cancel')
        end

        def finalize!
          super
          queue_webhooks_requests!('order.complete')
        end
      end
    end
  end
end
