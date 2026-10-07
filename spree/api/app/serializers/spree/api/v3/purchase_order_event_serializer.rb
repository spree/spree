module Spree
  module Api
    module V3
      # Payload of the purchase_order.* events. What was bought and what it
      # costs stay behind the Admin API: an integration reads them there with
      # a key scoped to purchasing.
      class PurchaseOrderEventSerializer < BaseSerializer
        typelize number: :string,
                 status: :string,
                 supplier_id: [:string, nullable: true],
                 destination_location_id: [:string, nullable: true],
                 ordered_at: [:string, nullable: true],
                 received_at: [:string, nullable: true],
                 closed_short_at: [:string, nullable: true]

        attributes :number, :status,
                   ordered_at: :iso8601, received_at: :iso8601, closed_short_at: :iso8601,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :supplier_id do |purchase_order|
          purchase_order.supplier&.prefixed_id
        end

        attribute :destination_location_id do |purchase_order|
          purchase_order.destination_location&.prefixed_id
        end
      end
    end
  end
end
