# frozen_string_literal: true

module Spree
  module Events
    class StockItemSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          count_on_hand: resource.count_on_hand,
          backorderable: resource.backorderable,
          stock_location_id: public_id(resource.stock_location),
          variant_id: public_id(resource.variant),
          deleted_at: timestamp(resource.deleted_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
