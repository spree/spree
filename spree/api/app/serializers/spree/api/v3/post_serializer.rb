# frozen_string_literal: true

module Spree
  module Api
    module V3
      class PostSerializer < BaseSerializer
        typelize title: :string, slug: :string,
                 meta_title: [:string, nullable: true], meta_description: [:string, nullable: true],
                 published_at: [:string, nullable: true],
                 author_id: [:string, nullable: true], post_category_id: [:string, nullable: true]

        attributes :title, :slug, :meta_title, :meta_description,
                   published_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

        attribute :author_id do |post|
          post.author&.prefixed_id
        end

        attribute :post_category_id do |post|
          post.post_category&.prefixed_id
        end
      end
    end
  end
end
