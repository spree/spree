module Spree
  module V2
    module Storefront
      class PostCategorySerializer < ::Spree::Api::V2::BaseSerializer
        set_type :post_category

        attributes :title, :slug, :created_at, :updated_at

        attribute :description do |category|
          category.description.to_plain_text if category.description.present?
        end

        has_many :posts, serializer: Spree::Api::Dependencies.storefront_post_serializer.constantize, record_type: :post, if: proc { |_record, params|
          params[:include_posts] == true
        } do |category|
          category.posts.published.by_newest
        end
      end
    end
  end
end