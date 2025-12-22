module Spree
  module Api
    module V2
      module Storefront
        class PostsController < ::Spree::Api::V2::ResourceController
          protected

          def sorted_collection
            collection_sorter.new(collection, params, allowed_sort_attributes).call
          end

          def collection
            @collection ||= collection_finder.new(scope: scope, params: finder_params).execute
          end

          def resource
            @resource ||= find_with_fallback_default_locale { scope.friendly.find(params[:id]) } || scope.friendly.find(params[:id])
          end

          def collection_finder
            Spree.api.storefront_posts_finder
          end

          def collection_sorter
            Spree.api.storefront_posts_sorter
          end

          def collection_serializer
            Spree::V2::Storefront::PostSerializer
          end

          def resource_serializer
            Spree::V2::Storefront::PostSerializer
          end

          def model_class
            Spree::Post
          end

          def scope
            super.published.includes(:post_category, image_attachment: :blob)
          end

          def allowed_sort_attributes
            super << :published_at << :title
          end
        end
      end
    end
  end
end
