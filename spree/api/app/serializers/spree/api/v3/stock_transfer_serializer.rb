# frozen_string_literal: true

module Spree
  module Api
    module V3
      class StockTransferSerializer < BaseSerializer
        typelize number: [:string, nullable: true], type: [:string, nullable: true],
                 reference: [:string, nullable: true],
                 source_location_id: [:string, nullable: true],
                 destination_location_id: [:string, nullable: true]

        attributes :number, :type, :reference,
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
