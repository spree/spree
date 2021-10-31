module Spree
  module Api
    module Webhooks
      module OrderDecorator
        def after_cancel
          super
          queue_webhooks_requests!('order.canceled')
        end

        def finalize!
          super
          queue_webhooks_requests!('order.placed')
        end
      end
    end
  end
end

Spree::Order.prepend(Spree::Api::Webhooks::OrderDecorator)
