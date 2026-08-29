module Spree
  module Api
    module V3
      module Admin
        module Companies
          # A business's own tax registration — the number that goes on its
          # invoices, which outranks the buyer's own when the two differ.
          #
          # Mirrors the customer registrations endpoint, including manual
          # re-validation: a registry answers only "valid now", so a number
          # verified last year may have been deregistered since.
          class TaxIdentifiersController < BaseController
            include Spree::Api::V3::TaxIdentifierValidation

            before_action :authorize_parent_access!
            # Re-declaring the filter replaces the inherited options, so the
            # standard actions have to be listed alongside the custom one.
            before_action :set_resource, only: [:show, :update, :destroy, :validate]

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

            def parent_association
              :tax_identifiers
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
