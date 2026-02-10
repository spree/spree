# frozen_string_literal: true

module Spree
  module Events
    class CustomerReturnSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          number: resource.number,
          stock_location_id: public_id(resource.stock_location),
          store_id: public_id(resource.store),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
