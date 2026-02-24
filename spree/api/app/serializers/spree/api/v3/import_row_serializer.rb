# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ImportRowSerializer < BaseSerializer
        typelize import_id: [:string, nullable: true], row_number: :number,
                 status: :string, validation_errors: 'unknown',
                 item_type: [:string, nullable: true], item_id: [:string, nullable: true]

        attributes :row_number, :status, :validation_errors, :item_type,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :import_id do |row|
          row.import&.prefixed_id
        end

        attribute :item_id do |row|
          row.item&.prefixed_id
        end
      end
    end
  end
end
