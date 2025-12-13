# frozen_string_literal: true

module Spree
  module Events
    class ReportSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          type: resource.type,
          store_id: resource.store_id,
          user_id: resource.user_id,
          currency: resource.currency,
          date_from: timestamp(resource.date_from),
          date_to: timestamp(resource.date_to),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
