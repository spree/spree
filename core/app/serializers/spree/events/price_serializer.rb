# frozen_string_literal: true

module Spree
  module Events
    class PriceSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          amount: money(resource.amount),
          compare_at_amount: money(resource.compare_at_amount),
          currency: resource.currency,
          variant_id: association_prefix_id(:variant),
          deleted_at: timestamp(resource.deleted_at),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
