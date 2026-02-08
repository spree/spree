# frozen_string_literal: true

module Spree
  module Events
    class ImportRowSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          import_id: association_prefix_id(:import),
          row_number: resource.row_number,
          status: resource.status,
          validation_errors: resource.validation_errors,
          item_type: resource.item_type,
          item_id: association_prefix_id(:item),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
