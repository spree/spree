# frozen_string_literal: true

module Spree
  module Events
    class WishlistSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          name: resource.name,
          is_private: resource.is_private,
          is_default: resource.is_default,
          user_id: resource.user_id,
          store_id: resource.store_id,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
