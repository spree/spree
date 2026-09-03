module Spree
  module Deliveries
    # The one-parcel shortcut behind `tracking:` on the fulfillment workflows
    # and the tracking field in the dashboard: records the number as the
    # fulfillment's primary consignment, or corrects the one it already has.
    #
    # A corrected number is a different parcel as far as the carrier is
    # concerned, so its journey starts over.
    class UpsertPrimary
      prepend Spree::ServiceModule::Base

      # @param fulfillment [Spree::Fulfillment]
      # @param tracking [String, nil] a carrier number or a full tracking link;
      #   blank is a no-op, so callers can pass an omitted parameter straight through
      # @param carrier [String, nil] free text; detected from the number when omitted
      # @return [Spree::ServiceModule::Result] the delivery, or nil when nothing was asked
      def call(fulfillment:, tracking:, carrier: nil)
        return success(nil) if tracking.blank?

        primary = fulfillment.primary_delivery
        return Spree.delivery_create_service.call(owner: fulfillment, tracking_number: tracking, carrier: carrier) if primary.nil?

        attributes = { tracking_number: tracking.to_s.squish }
        attributes[:carrier] = carrier if carrier.present?
        attributes[:status] = 'pending' if attributes[:tracking_number] != primary.tracking_number

        primary.update(attributes) ? success(primary) : failure(primary)
      end
    end
  end
end
