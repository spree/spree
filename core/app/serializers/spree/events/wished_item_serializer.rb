# frozen_string_literal: true

module Spree
  module Events
    class WishedItemSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          quantity: resource.quantity,
          variant_id: public_id(resource.variant),
          wishlist_id: public_id(resource.wishlist),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
