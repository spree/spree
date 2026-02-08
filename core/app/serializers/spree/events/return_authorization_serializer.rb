# frozen_string_literal: true

module Spree
  module Events
    class ReturnAuthorizationSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          number: resource.number,
          state: resource.state.to_s,
          order_id: association_prefix_id(:order),
          stock_location_id: association_prefix_id(:stock_location),
          return_authorization_reason_id: association_prefix_id(:reason),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
