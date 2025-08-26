module Spree
  module Api
    module V2
      module Storefront
        class PostsController < ::Spree::Api::V2::ResourceController
          protected

          def collection
            @collection ||= collection_finder.new(scope: scope, params: finder_params).execute
          end

          def resource
            @resource ||= find_with_fallback_default_locale { scope.friendly.find(params[:id]) } || scope.friendly.find(params[:id])
          end

          def collection_finder
            Spree::Api::Dependencies.storefront_posts_finder.constantize
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
            super.published
          end

          def allowed_sort_attributes
            super << :published_at
          end
        end
      end
    end
  end
end
