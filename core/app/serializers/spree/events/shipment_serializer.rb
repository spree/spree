# frozen_string_literal: true

module Spree
  module Events
    class ShipmentSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          number: resource.number,
          state: resource.state.to_s,
          tracking: resource.tracking,
          cost: money(resource.cost),
          order_id: public_id(resource.order),
          stock_location_id: public_id(resource.stock_location),
          shipped_at: timestamp(resource.shipped_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
