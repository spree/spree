module Spree
  module Api
    module V3
      module Admin
        class TaxCategoriesController < ResourceController
          scoped_resource :settings

          request_params :tax_category do
            string :name, required: :create
            string :tax_code, :description, nullable: true
            boolean :is_default
          end

          protected

          def model_class
            Spree::TaxCategory
          end

          def serializer_class
            Spree.api.admin_tax_category_serializer
          end
        end
      end
    end
  end
end
