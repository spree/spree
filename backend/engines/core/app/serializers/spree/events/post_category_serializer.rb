# frozen_string_literal: true

module Spree
  module Events
    class PostCategorySerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          title: resource.title,
          slug: resource.slug,
          store_id: public_id(resource.store),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
