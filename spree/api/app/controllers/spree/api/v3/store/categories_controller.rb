module Spree
  module Api
    module V3
      module Store
        class CategoriesController < ResourceController
          include Spree::Api::V3::HttpCaching

          protected

          def model_class
            Spree::Category
          end

          def serializer_class
            Spree.api.category_serializer
          end

          # Find category by permalink or prefixed ID with i18n scope for SEO-friendly URLs
          # Falls back to default locale if category is not found in the current locale
          def find_resource
            id = params[:id]
            if id.to_s.start_with?('txn_')
              scope.find_by_prefix_id!(id)
            else
              find_with_fallback_default_locale { scope.i18n.find_by!(permalink: id) }
            end
          end

          def collection_includes
            [:taxonomy]
          end
        end
      end
    end
  end
end
