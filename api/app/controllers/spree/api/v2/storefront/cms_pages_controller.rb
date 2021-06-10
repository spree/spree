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
            @resource ||= scope.find_by(slug: params[:slug])
          end

          def resource_serializer
            Spree::Api::Dependencies.storefront_cms_page_serializer.constantize
          end

          def collection_serializer
            Spree::Api::Dependencies.storefront_cms_page_serializer.constantize
          end

          def scope
            super.by_store(current_store).by_locale(I18n.locale).linkable
          end
        end
      end
    end
  end
end
