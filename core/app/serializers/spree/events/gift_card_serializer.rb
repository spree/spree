# frozen_string_literal: true

module Spree
  module Events
    class GiftCardSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          code: resource.code,
          state: resource.state.to_s,
          amount: money(resource.amount),
          amount_used: money(resource.amount_used),
          amount_authorized: money(resource.amount_authorized),
          amount_remaining: money(resource.amount_remaining),
          currency: resource.currency,
          expires_at: resource.expires_at&.iso8601,
          redeemed_at: timestamp(resource.redeemed_at),
          user_id: resource.user_id,
          store_id: resource.store_id,
          gift_card_batch_id: resource.gift_card_batch_id,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
