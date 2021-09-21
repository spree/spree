module Spree
  module Api
    module Webhooks
      module Shipment
        private

        def after_ship
          super
          Spree::Webhooks::Endpoints::QueueRequests.call(event: 'shipment.ship', payload: {})
        end
      end
    end
  end
end
