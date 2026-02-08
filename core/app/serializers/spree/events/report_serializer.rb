# frozen_string_literal: true

module Spree
  module Events
    class ReportSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          type: resource.type,
          store_id: association_prefix_id(:store),
          user_id: association_prefix_id(:user),
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
