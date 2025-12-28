# frozen_string_literal: true

module Spree
  module Events
    class StockMovementSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          quantity: resource.quantity,
          action: resource.action,
          originator_type: resource.originator_type,
          originator_id: resource.originator_id,
          stock_item_id: resource.stock_item_id,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
