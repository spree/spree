# frozen_string_literal: true

module Spree
  module Events
    class StoreCreditSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          amount: money(resource.amount),
          amount_used: money(resource.amount_used),
          amount_authorized: money(resource.amount_authorized),
          currency: resource.currency,
          memo: resource.memo,
          user_id: public_id(resource.user),
          category_id: public_id(resource.category),
          type_id: public_id(resource.credit_type),
          store_id: public_id(resource.store),
          created_by_id: public_id(resource.created_by),
          originator_type: resource.originator_type,
          originator_id: public_id(resource.originator),
          deleted_at: timestamp(resource.deleted_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
