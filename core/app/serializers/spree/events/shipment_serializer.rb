# frozen_string_literal: true

module Spree
  module Events
    class ShipmentSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          number: resource.number,
          state: resource.state.to_s,
          tracking: resource.tracking,
          cost: money(resource.cost),
          order_id: association_prefix_id(:order),
          stock_location_id: association_prefix_id(:stock_location),
          shipped_at: timestamp(resource.shipped_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
