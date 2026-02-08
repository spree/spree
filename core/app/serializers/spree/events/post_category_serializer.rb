# frozen_string_literal: true

module Spree
  module Events
    class PostCategorySerializer < BaseSerializer
      protected

      def attributes
        {
          id: resource.prefix_id,
          title: resource.title,
          slug: resource.slug,
          store_id: association_prefix_id(:store),
          created_at: timestamp(resource.created_at),
          updated_at: timestamp(resource.updated_at)
        }
      end
    end
  end
end
