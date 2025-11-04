module Spree
  module Api
    module V3
      module Storefront
        class PagesController < ResourceController
          # Public endpoint - no authentication required

          protected

          def scope
            super.without_previews.where(pageable: current_store)
          end

          def model_class
            Spree::Page
          end

          def serializer_class
            Spree::Api::Dependencies.v3_storefront_page_serializer.constantize
          end

          # Not needed for index/show
          def permitted_params
            {}
          end
        end
      end
    end
  end
end
