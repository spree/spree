module Spree
  module Shipments
    # @deprecated Use {Spree::Fulfillments::Update}; removed in 6.1.
    class Update
      def self.call(shipment:, shipment_attributes: {}, &block)
        Spree::Deprecation.warn('Spree::Shipments::Update is deprecated and will be removed in Spree 6.1. Use Spree::Fulfillments::Update instead.')
        Spree::Fulfillments::Update.call(fulfillment: shipment, fulfillment_attributes: shipment_attributes, &block)
      end
    end
  end
end
