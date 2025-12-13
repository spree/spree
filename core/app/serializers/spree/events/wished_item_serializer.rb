# frozen_string_literal: true

module Spree
  module Events
    class WishedItemSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          quantity: resource.quantity,
          variant_id: resource.variant_id,
          wishlist_id: resource.wishlist_id,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
