module Spree
  module Api
    module V3
      # Payload of the shipping_label.* events: the tracking a customer is
      # also shown. What the carrier charged, the provider's ids and the file
      # stay behind the Admin API.
      class ShippingLabelEventSerializer < BaseSerializer
        typelize owner_id: :string,
                 owner_type: [:string, enum: %w[fulfillment return]],
                 status: [:string, enum: Spree::ShippingLabel.statuses, enum_type_name: 'ShippingLabelStatus'],
                 carrier: [:string, nullable: true],
                 service: [:string, nullable: true],
                 tracking_number: [:string, nullable: true],
                 refunded_at: [:string, nullable: true]

        attributes :status, :carrier, :service, :tracking_number,
                   refunded_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

        attribute :owner_id do |shipping_label|
          shipping_label.owner&.prefixed_id
        end

        attribute :owner_type do |shipping_label|
          shipping_label.owner_type == 'Spree::Return' ? 'return' : 'fulfillment'
        end
      end
    end
  end
end
