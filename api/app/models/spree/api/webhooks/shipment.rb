module Spree
  module Api
    module Webhooks
      module Shipment
        def ship
          super
          Spree::Webhooks::Endpoints::QueueRequests.call(event: 'shipment.ship', payload: {})
        end
      end
    end
  end
end
