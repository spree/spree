# frozen_string_literal: true

module Spree
  module Events
    class ExportSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          number: resource.number,
          type: resource.type,
          format: resource.format,
          user_id: resource.user_id,
          store_id: resource.store_id,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
