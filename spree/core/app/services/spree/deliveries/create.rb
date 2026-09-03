module Spree
  module Deliveries
    # Records a consignment on its owner: a parcel's tracking number, a
    # forwarder's PRO or container number, or the number printed on a label
    # that was just bought (docs/plans/6.0-shipping-labels-and-deliveries.md).
    #
    # The one write path for a delivery row — the +tracking:+ shortcut on
    # Spree::Fulfillments::Fulfill / Update and the label workflows all come
    # through here. A plain service: no hook has been earned yet.
    class Create
      prepend Spree::ServiceModule::Base

      # @param owner [Spree::Fulfillment, Spree::Return]
      # @param tracking_number [String] a carrier number, or a full tracking
      #   link pasted whole — which then also becomes +tracking_url+
      # @param carrier [String, nil] free text; detected from the number when omitted
      # @param tracking_url [String, nil]
      # @param service [String, nil]
      # @param shipping_label [Spree::ShippingLabel, nil] the label that minted this delivery
      # @param status [String] the carrier status to start at
      # @return [Spree::ServiceModule::Result] the delivery on success
      def call(owner:, tracking_number:, carrier: nil, tracking_url: nil, service: nil, shipping_label: nil, status: 'pending')
        delivery = owner.deliveries.new(
          store: owner.store,
          tracking_number: tracking_number,
          carrier: carrier.presence,
          tracking_url: tracking_url.presence,
          service: service.presence,
          shipping_label: shipping_label,
          status: status
        )
        delivery[:tracking_url] ||= delivery.tracking_number if delivery.pasted_link?

        delivery.save ? success(delivery) : failure(delivery)
      end
    end
  end
end
