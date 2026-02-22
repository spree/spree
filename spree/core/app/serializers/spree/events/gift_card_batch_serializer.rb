# frozen_string_literal: true

module Spree
  module Events
    class GiftCardBatchSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          codes_count: resource.codes_count,
          amount: money(resource.amount),
          currency: resource.currency,
          prefix: resource.prefix,
          expires_at: resource.expires_at&.to_s,
          store_id: public_id(resource.store),
          created_by_id: public_id(resource.created_by),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
