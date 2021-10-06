module Spree
  module Api
    module Webhooks
      module Payment
        def after_void
          super
          queue_webhooks_requests!('payment.void')
        end
      end
    end
  end
end
