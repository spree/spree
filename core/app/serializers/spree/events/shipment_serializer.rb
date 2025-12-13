# frozen_string_literal: true

module Spree
  module Events
    class ShipmentSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          number: resource.number,
          state: resource.state.to_s,
          tracking: resource.tracking,
          cost: money(resource.cost),
          order_id: resource.order_id,
          stock_location_id: resource.stock_location_id,
          shipped_at: timestamp(resource.shipped_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
