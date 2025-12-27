# frozen_string_literal: true

module Spree
  module Events
    class ImportSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          number: resource.number,
          type: resource.type,
          status: resource.status.to_s,
          owner_type: resource.owner_type,
          owner_id: resource.owner_id,
          user_id: resource.user_id,
          rows_count: resource.rows_count,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
