# frozen_string_literal: true

module Spree
  module Events
    class ReturnAuthorizationSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          number: resource.number,
          state: resource.state.to_s,
          order_id: resource.order_id,
          stock_location_id: resource.stock_location_id,
          return_authorization_reason_id: resource.return_authorization_reason_id,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
