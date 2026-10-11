module Spree
  module Api
    module V3
      module Admin
        # Admin CRUD for `Spree::CustomerGroup`. Scoped to the current
        # store so groups from sibling stores don't leak into pickers.
        class CustomerGroupsController < ResourceController
          scoped_resource :customers

          request_params :customer_group do |body|
            body.attribute :name, :string, required: true, on: :create, example: 'Wholesale'
            body.attribute :description, :string, nullable: true, example: 'B2B accounts'
            body.attribute :customer_ids, :array, of: :id,
              example: %w[cus_UkLWZg9DAJ],
              description: "Replaces the group's members."
          end

          protected

          def model_class
            Spree::CustomerGroup
          end

          def serializer_class
            Spree.api.admin_customer_group_serializer
          end

          def permitted_params
            params.permit(*permitted_attributes)
          end
        end
      end
    end
  end
end
