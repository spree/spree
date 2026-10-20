# frozen_string_literal: true

module Spree
  module Api
    module V3
      class ImportRowSerializer < BaseSerializer
        typelize import_id: [:string, nullable: true], row_number: :number,
                 status: [:string, enum: Spree::ImportRow.statuses, enum_type_name: 'ImportRowStatus'], validation_errors: [:string, nullable: true],
                 item_type: [:string, nullable: true], item_id: [:string, nullable: true]

        attributes :row_number, :status, :validation_errors,
                   created_at: :iso8601, updated_at: :iso8601

        prefixed_id_attributes :import

        # `"product"` / `"variant"`, not the polymorphic class name.
        attribute :item_type do |row|
          Spree::Base.polymorphic_api_type(row.item_type)
        end

        prefixed_id_attributes :item
      end
    end
  end
end
