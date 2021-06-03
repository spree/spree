module Spree
  module Api
    module V2
      module Storefront
        class CmsPagesController < ::Spree::Api::V2::ResourceController
          private

          def model_class
            Spree::CmsPage
          end

          def resource
            @resource ||= scope.find_by!(title: params[:title])
          end

          def resource_serializer
            Spree::Api::Dependencies.storefront_cms_page_serializer.constantize
          end

          def collection_serializer
            Spree::Api::Dependencies.storefront_cms_page_serializer.constantize
          end
        end
      end
    end
  end
end
