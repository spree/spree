module Spree
  module Api
    module V3
      module Store
        module Customer
          # The signed-in customer's own tax registration. Singular: one
          # registration per kind, and the storefront deals in one at a time.
          class TaxIdentifiersController < Store::BaseController
            prepend_before_action :require_authentication!

            # GET /api/v3/store/customers/me/tax_identifier
            def show
              return head :not_found if tax_identifier.nil?

              render json: serialize_resource(tax_identifier)
            end

            # PUT /api/v3/store/customers/me/tax_identifier
            #
            # Upsert rather than create/update: a buyer has one registration of a
            # kind, and asking the storefront to know whether it exists yet would
            # be bookkeeping we can do ourselves.
            def update
              resource = current_user.tax_identifiers.find_or_initialize_by(kind: permitted_params[:kind])
              resource.value = permitted_params[:value]

              if resource.save
                render json: serialize_resource(resource), status: resource.previously_new_record? ? :created : :ok
              else
                render_validation_error(resource.errors)
              end
            end

            # DELETE /api/v3/store/customers/me/tax_identifier
            def destroy
              return head :not_found if tax_identifier.nil?

              tax_identifier.destroy!
              head :no_content
            end

            protected

            def serializer_class
              Spree.api.tax_identifier_serializer
            end

            def permitted_params
              params.permit(:kind, :value)
            end

            private

            def tax_identifier
              @tax_identifier ||= if params[:kind].present?
                                    current_user.tax_identifiers.for_kind(params[:kind]).first
                                  else
                                    current_user.tax_identifiers.first
                                  end
            end
          end
        end
      end
    end
  end
end
