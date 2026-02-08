# frozen_string_literal: true

module Spree
  module Events
    class ExportSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          number: resource.number,
          type: resource.type,
          format: resource.format,
          user_id: public_id(resource.user),
          store_id: public_id(resource.store),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
