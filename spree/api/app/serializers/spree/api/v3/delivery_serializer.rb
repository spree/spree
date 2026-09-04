module Spree
  module Api
    module V3
      # One consignment's carrier journey — the customer's "where is my
      # parcel" answer, so it sits on the public serializer beside the
      # fulfillment's tracking summary.
      class DeliverySerializer < BaseSerializer
        typelize tracking_number: :string,
                 tracking_url: [:string, nullable: true],
                 carrier: [:string, nullable: true],
                 carrier_name: [:string, nullable: true],
                 service: [:string, nullable: true],
                 status: :string,
                 estimated_delivery_at: [:string, nullable: true],
                 delivered_at: [:string, nullable: true]

        attributes :tracking_number, :carrier, :carrier_name, :service, :status

        # The best link for this consignment: the one stored on the row, or
        # the one derived from its carrier and number.
        attribute :tracking_url do |delivery|
          delivery.resolved_tracking_url
        end

        attributes estimated_delivery_at: :iso8601, delivered_at: :iso8601
      end
    end
  end
end
