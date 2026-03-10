module Spree
  module Api
    module V3
      module Admin
        class CategoriesController < ResourceController
          protected

          def model_class
            Spree::Category
          end

          def serializer_class
            Spree.api.admin_category_serializer
          end

          def scope
            super.where(taxonomy: current_store.taxonomies)
          end
        end
      end
    end
  end
end
