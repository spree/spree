# frozen_string_literal: true

module Spree
  module Events
    class WishlistSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          name: resource.name,
          is_private: resource.is_private,
          is_default: resource.is_default,
          user_id: association_prefix_id(:user),
          store_id: association_prefix_id(:store),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
