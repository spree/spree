# frozen_string_literal: true

module Spree
  module Events
    class StoreCreditSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          amount: money(resource.amount),
          amount_used: money(resource.amount_used),
          amount_authorized: money(resource.amount_authorized),
          currency: resource.currency,
          memo: resource.memo,
          user_id: resource.user_id,
          category_id: resource.category_id,
          type_id: resource.type_id,
          store_id: resource.store_id,
          created_by_id: resource.created_by_id,
          originator_type: resource.originator_type,
          originator_id: resource.originator_id,
          deleted_at: timestamp(resource.deleted_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
