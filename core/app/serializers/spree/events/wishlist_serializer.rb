# frozen_string_literal: true

module Spree
  module Events
    class WishlistSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          name: resource.name,
          is_private: resource.is_private,
          is_default: resource.is_default,
          user_id: public_id(resource.user),
          store_id: public_id(resource.store),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
