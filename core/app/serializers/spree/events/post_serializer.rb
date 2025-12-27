# frozen_string_literal: true

module Spree
  module Events
    class PostSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.id,
          title: resource.title,
          slug: resource.slug,
          meta_title: resource.meta_title,
          meta_description: resource.meta_description,
          published_at: timestamp(resource.published_at),
          deleted_at: timestamp(resource.deleted_at),
          author_id: resource.author_id,
          post_category_id: resource.post_category_id,
          store_id: resource.store_id,
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
