module Spree
  module Api
    module V3
      module Admin
        module Customers
          class TaxIdentifiersController < BaseController
            scoped_resource :customers

            include Spree::Api::V3::TaxIdentifierValidation

            request_params 'TaxIdentifierParams' do
              string :kind, example: 'gb_vat',
                            description: "#{Spree::Api::V3::TaxIdentifierRequestSchema::KIND_DESCRIPTION} Required when creating."
              string :value, example: 'GB123456789', description: 'Required when creating.'
            end

            # Re-declaring the filter replaces the inherited options, so the
            # standard actions have to be listed alongside the custom one.
            before_action :set_resource, only: [:show, :update, :destroy, :validate]

            # POST /api/v3/admin/customers/:customer_id/tax_identifiers/:id/validate
            #
            # Re-asks the registry. Manual because a registry answers only "valid
            # now": a number verified last year may have been deregistered since,
            # and staff need a way to check without editing the row.

            protected

            def model_class
              Spree::TaxIdentifier
            end

            def serializer_class
              Spree.api.admin_tax_identifier_serializer
            end

            def scope
              @parent.tax_identifiers
            end

            def permitted_params
              params.permit(*declared_permitted_attributes)
            end
          end
        end
      end
    end
  end
end
