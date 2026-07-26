# frozen_string_literal: true

module Spree
  module Api
    module V3
      class StockTransferSerializer < BaseSerializer
        # `type` is not exposed: Spree::StockTransfer has no STI subclasses, so
        # the column is a legacy vestige that is always nil. The admin
        # serializer already omits it.
        typelize number: [:string, nullable: true],
                 reference: [:string, nullable: true],
                 source_location_id: [:string, nullable: true],
                 destination_location_id: [:string, nullable: true]

        attributes :number, :reference,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :source_location_id do |transfer|
          transfer.source_location&.prefixed_id
        end

        attribute :destination_location_id do |transfer|
          transfer.destination_location&.prefixed_id
        end
      end
    end
  end
end
