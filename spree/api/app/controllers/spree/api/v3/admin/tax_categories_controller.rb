module Spree
  module Api
    module V3
      module Admin
        class TaxCategoriesController < ResourceController
          scoped_resource :settings

          request_params :tax_category do |body|
            body.attribute :name, :string, required: true, on: :create
            body.attribute :tax_code, :string, nullable: true
            body.attribute :description, :string, nullable: true
            body.attribute :is_default, :boolean
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
