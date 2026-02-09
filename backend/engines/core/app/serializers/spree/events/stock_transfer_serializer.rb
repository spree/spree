# frozen_string_literal: true

module Spree
  module Events
    class StockTransferSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          number: resource.number,
          type: resource.type,
          reference: resource.reference,
          source_location_id: public_id(resource.source_location),
          destination_location_id: public_id(resource.destination_location),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
