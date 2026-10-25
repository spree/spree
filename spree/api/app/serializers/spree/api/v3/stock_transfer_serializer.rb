# frozen_string_literal: true

module Spree
  module Api
    module V3
      class StockTransferSerializer < BaseSerializer
        # Both warehouses are required now: receiving from a supplier is a
        # Spree::PurchaseOrder, not a transfer with a missing source
        # (docs/plans/6.0-inventory-operations.md).
        typelize number: :string,
                 reference: [:string, nullable: true],
                 source_location_id: :string,
                 destination_location_id: :string

        attributes :number, :reference,
                   created_at: :iso8601, updated_at: :iso8601

        prefixed_id_attributes :source_location, :destination_location
      end
    end
  end
end
