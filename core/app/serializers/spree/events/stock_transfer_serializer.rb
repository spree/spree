# frozen_string_literal: true

module Spree
  module Events
    class StockTransferSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          number: resource.number,
          type: resource.type,
          reference: resource.reference,
          source_location_id: association_prefix_id(:source_location),
          destination_location_id: association_prefix_id(:destination_location),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
