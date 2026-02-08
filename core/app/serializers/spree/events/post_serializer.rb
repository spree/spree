# frozen_string_literal: true

module Spree
  module Events
    class PostSerializer < BaseSerializer
      protected

      def attributes
        {
          id: public_id(resource),
          title: resource.title,
          slug: resource.slug,
          meta_title: resource.meta_title,
          meta_description: resource.meta_description,
          published_at: timestamp(resource.published_at),
          deleted_at: timestamp(resource.deleted_at),
          author_id: public_id(resource.author),
          post_category_id: public_id(resource.post_category),
          store_id: public_id(resource.store),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
