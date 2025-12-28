# frozen_string_literal: true

module Spree
  module Events
    class ImportRowSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          import_id: resource.import_id,
          row_number: resource.row_number,
          status: resource.status,
          validation_errors: resource.validation_errors,
          item_type: resource.item_type,
          item_id: resource.item_id,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
