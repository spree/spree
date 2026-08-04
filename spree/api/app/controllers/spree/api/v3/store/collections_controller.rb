module Spree
  module Api
    module V3
      module Store
        class CollectionsController < ResourceController
          include Spree::Api::V3::HttpCaching

          protected

          def model_class
            Spree::Collection
          end

          def serializer_class
            Spree.api.collection_serializer
          end

          # Find by permalink or prefixed ID (SEO-friendly URLs), i18n-scoped with a
          # fallback to the default locale — mirrors the Categories controller.
          def find_resource
            id = params[:id]
            if id.to_s.start_with?('coll_')
              scope.find_by_prefix_id!(id)
            else
              find_with_fallback_default_locale { scope.i18n.find_by!(permalink: id) }
            end
          end
        end
      end
    end
  end
end
