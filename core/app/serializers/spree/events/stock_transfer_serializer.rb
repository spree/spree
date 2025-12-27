# frozen_string_literal: true

module Spree
  module Events
    class StockTransferSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          number: resource.number,
          type: resource.type,
          reference: resource.reference,
          source_location_id: resource.source_location_id,
          destination_location_id: resource.destination_location_id,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
