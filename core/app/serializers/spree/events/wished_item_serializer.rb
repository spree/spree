# frozen_string_literal: true

module Spree
  module Events
    class WishedItemSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          quantity: resource.quantity,
          variant_id: association_prefix_id(:variant),
          wishlist_id: association_prefix_id(:wishlist),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
