# frozen_string_literal: true

module Spree
  module Events
    class PriceSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          amount: money(resource.amount),
          compare_at_amount: money(resource.compare_at_amount),
          currency: resource.currency,
          variant_id: public_id(resource.variant),
          deleted_at: timestamp(resource.deleted_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
