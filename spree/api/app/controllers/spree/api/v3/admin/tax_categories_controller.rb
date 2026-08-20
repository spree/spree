module Spree
  module Api
    module V3
      module Admin
        class TaxCategoriesController < ResourceController
          scoped_resource :settings

          protected

          def model_class
            Spree::TaxCategory
          end

          def serializer_class
            Spree.api.admin_tax_category_serializer
          end

          def resource_permitted_attributes
            [:name, :tax_code, :description, :is_default]
          end
        end
      end
    end
  end
end
