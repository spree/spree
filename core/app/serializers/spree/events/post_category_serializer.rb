# frozen_string_literal: true

module Spree
  module Events
    class PostCategorySerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          title: resource.title,
          slug: resource.slug,
          store_id: resource.store_id,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
