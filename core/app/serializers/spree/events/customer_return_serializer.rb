# frozen_string_literal: true

module Spree
  module Events
    class CustomerReturnSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          number: resource.number,
          stock_location_id: association_prefix_id(:stock_location),
          store_id: association_prefix_id(:store),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
