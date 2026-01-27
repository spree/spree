module Spree
  module Api
    module V2
      module Storefront
        class PostCategoriesController < ::Spree::Api::V2::ResourceController
          protected

          def collection
            @collection ||= scope
          end

          def resource
            @resource ||= find_with_fallback_default_locale { scope.friendly.find(params[:id]) } || scope.friendly.find(params[:id])
          end

          def collection_serializer
            Spree::V2::Storefront::PostCategorySerializer
          end

          def resource_serializer
            Spree::V2::Storefront::PostCategorySerializer
          end

          def model_class
            Spree::PostCategory
          end

          def serializer_params
            super.merge(include_posts: action_name == 'show')
          end
        end
      end
    end
  end
end
