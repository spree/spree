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
      # @param adopt [Boolean] when a delivery for this number already exists
      #   on the owner, fill its blanks and return it rather than refusing.
      #   A label binding the number the merchant typed by hand is the same
      #   consignment; a merchant recording that number twice is not.
      # @return [Spree::ServiceModule::Result] the delivery on success
      def call(owner:, tracking_number:, carrier: nil, tracking_url: nil, service: nil,
               shipping_label: nil, status: 'pending', adopt: false)
        existing = adopt ? owner.deliveries.find_by(tracking_number: tracking_number.to_s.squish) : nil
        delivery = existing || owner.deliveries.new(store: owner.store, tracking_number: tracking_number, status: status)

        # Blanks are filled, never overwritten: whichever of the two arrived
        # first said what it knew.
        delivery.carrier = carrier.presence || delivery.carrier
        delivery.service = service.presence || delivery.service
        delivery.tracking_url = tracking_url.presence || delivery.tracking_url
        delivery.shipping_label = shipping_label if shipping_label
        delivery.tracking_url ||= delivery.tracking_number if delivery.pasted_link?

        return failure(delivery) unless delivery.save

        # A parcel that has not arrived makes a delivered fulfillment untrue.
        recalculate(owner)

        success(delivery)
      end

      private

      def recalculate(owner)
        return unless owner.is_a?(Spree::Fulfillment)

        Spree.fulfillment_recalculate_delivery_service.call(fulfillment: owner)
      end
    end
  end
end
