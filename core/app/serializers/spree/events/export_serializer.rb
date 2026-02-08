# frozen_string_literal: true

module Spree
  module Events
    class ExportSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          number: resource.number,
          type: resource.type,
          format: resource.format,
          user_id: association_prefix_id(:user),
          store_id: association_prefix_id(:store),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
