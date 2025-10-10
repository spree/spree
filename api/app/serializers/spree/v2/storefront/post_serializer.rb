module Spree
  module V2
    module Storefront
      class PostSerializer < ::Spree::Api::V2::BaseSerializer
        include Spree::Api::V2::PublicMetafieldsConcern

        set_type :post

        attributes :title, :slug, :published_at, :meta_title, :meta_description, :created_at, :updated_at

        attribute :excerpt do |post|
          post.excerpt.to_plain_text if post.excerpt.present?
        end

        attribute :content do |post|
          post.content.to_plain_text if post.content.present?
        end

        attribute :content_html do |post|
          post.content.to_s if post.content.present?
        end

        attribute :description do |post|
          post.description
        end

        attribute :shortened_description do |post|
          post.shortened_description
        end

        attribute :author_name do |post|
          post.author_name
        end

        attribute :post_category_title do |post|
          post.post_category_title
        end

        attribute :tags do |post|
          post.tag_list
        end

        attribute :image_url do |post, params|
          url_helpers.cdn_image_url(post.image.attachment) if post.image.present? && post.image.attached?
        end

        belongs_to :post_category, serializer: Spree::Api::Dependencies.storefront_post_category_serializer.constantize, record_type: :post_category
      end
    end
  end
end
