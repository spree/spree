module Spree
  module Api
    module V3
      module Admin
        # Business customers. A company is a customer record, so it answers to
        # the customer scopes rather than earning one of its own.
        class CompaniesController < ResourceController
          scoped_resource :customers

          protected

          def model_class
            Spree::Company
          end

          def serializer_class
            Spree.api.admin_company_serializer
          end

          def scope
            super.for_store(current_store)
          end

          def collection_includes
            [:company_locations]
          end

          def permitted_params
            params.permit(*model_additional_permitted_attributes, :name, :external_id, metadata: {})
          end
        end
      end
    end
  end
end
