module Spree
  module Api
    module V3
      module Admin
        module Customers
          class TaxIdentifiersController < BaseController
            scoped_resource :customers

            # Re-declaring the filter replaces the inherited options, so the
            # standard actions have to be listed alongside the custom one.
            before_action :set_resource, only: [:show, :update, :destroy, :validate]

            # POST /api/v3/admin/customers/:customer_id/tax_identifiers/:id/validate
            #
            # Re-asks the registry. Manual because a registry answers only "valid
            # now": a number verified last year may have been deregistered since,
            # and staff need a way to check without editing the row.
            def validate
              authorize_resource!(@resource, :update)

              unless @resource.validatable?
                render_error(
                  code: 'tax_id_not_validatable',
                  message: "No validator is registered for tax identifier kind '#{@resource.kind}'",
                  status: :unprocessable_content
                )
                return
              end

              Spree::TaxIdentifiers::ValidateJob.perform_later(@resource.id)
              @resource.update_columns(validation_status: 'pending', validated_at: nil, updated_at: Time.current)

              render json: serialize_resource(@resource.reload), status: :accepted
            end

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
              params.permit(:kind, :value)
            end
          end
        end
      end
    end
  end
end
