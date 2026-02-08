# frozen_string_literal: true

module Spree
  module Events
    class StockMovementSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          quantity: resource.quantity,
          action: resource.action,
          originator_type: resource.originator_type,
          originator_id: public_id(resource.originator),
          stock_item_id: public_id(resource.stock_item),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
