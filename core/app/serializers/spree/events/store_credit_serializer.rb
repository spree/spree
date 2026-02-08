# frozen_string_literal: true

module Spree
  module Events
    class StoreCreditSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          amount: money(resource.amount),
          amount_used: money(resource.amount_used),
          amount_authorized: money(resource.amount_authorized),
          currency: resource.currency,
          memo: resource.memo,
          user_id: association_prefix_id(:user),
          category_id: association_prefix_id(:category),
          type_id: association_prefix_id(:credit_type),
          store_id: association_prefix_id(:store),
          created_by_id: association_prefix_id(:created_by),
          originator_type: resource.originator_type,
          originator_id: association_prefix_id(:originator),
          deleted_at: timestamp(resource.deleted_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
