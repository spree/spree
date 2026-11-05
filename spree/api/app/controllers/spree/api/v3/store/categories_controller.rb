module Spree
  module Api
    module V3
      module Store
        class CategoriesController < ResourceController
          include Spree::Api::V3::HttpCaching
          include Spree::Api::V3::Store::PermalinkLookup

          protected

          def model_class
            Spree::Category
          end

          def serializer_class
            Spree.api.category_serializer
          end

          # Exclude automatic (rule-based) rows still living in spree_categories
          # until the Phase 4 migration moves them to Collections (removed in 6.1).
          def scope
            super.manual
          end

          def find_resource
            find_by_id_or_permalink!(scope, params[:id])
          end
        end
      end
    end
  end
end
