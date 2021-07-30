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
            @resource ||= scope.find_by(slug: params[:id]) || scope.find(params[:id])
          end

          def resource_serializer
            Spree::Api::Dependencies.storefront_cms_page_serializer.constantize
          end

          def collection_serializer
            Spree::Api::Dependencies.storefront_cms_page_serializer.constantize
          end

          def collection_finder
            Spree::Api::Dependencies.storefront_cms_page_finder.constantize
          end

          def scope
            super.by_locale(I18n.locale)
          end

          def scope_includes
            {
              cms_sections: :linked_resource
            }
          end
        end
      end
    end
  end
end
