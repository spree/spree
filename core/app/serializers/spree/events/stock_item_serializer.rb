# frozen_string_literal: true

module Spree
  module Events
    class StockItemSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          count_on_hand: resource.count_on_hand,
          backorderable: resource.backorderable,
          stock_location_id: resource.stock_location_id,
          variant_id: resource.variant_id,
          deleted_at: timestamp(resource.deleted_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
