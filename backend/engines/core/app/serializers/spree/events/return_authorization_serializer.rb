# frozen_string_literal: true

module Spree
  module Events
    class ReturnAuthorizationSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          number: resource.number,
          state: resource.state.to_s,
          order_id: public_id(resource.order),
          stock_location_id: public_id(resource.stock_location),
          return_authorization_reason_id: public_id(resource.reason),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
