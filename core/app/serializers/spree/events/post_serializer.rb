# frozen_string_literal: true

module Spree
  module Events
    class PostSerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          title: resource.title,
          slug: resource.slug,
          meta_title: resource.meta_title,
          meta_description: resource.meta_description,
          published_at: timestamp(resource.published_at),
          deleted_at: timestamp(resource.deleted_at),
          author_id: association_prefix_id(:author),
          post_category_id: association_prefix_id(:post_category),
          store_id: association_prefix_id(:store),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
