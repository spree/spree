module Spree
  module Api
    module Webhooks
      module Shipment
        def after_ship
          super
          queue_webhooks_requests!('shipment.ship')
        end
      end
    end
  end
end
