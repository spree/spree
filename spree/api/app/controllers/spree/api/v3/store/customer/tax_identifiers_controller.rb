module Spree
  module Api
    module V3
      module Store
        module Customer
          # The signed-in customer's own tax registrations — one per kind, since a
          # business can be registered under more than one regime.
          #
          # Reads come in two shapes: the list, for a checkout page offering the
          # buyer a choice, and the singular one for reading or upserting a given
          # kind without knowing whether it exists yet.
          class TaxIdentifiersController < Store::BaseController
            prepend_before_action :require_authentication!

            # The singular endpoints address one registration, and a buyer can
            # hold several. Without a kind, `first` picked whichever row the
            # database happened to return — so a DELETE removed a registration
            # the buyer never named and could not predict.
            before_action :require_kind!, only: %i[show update destroy]

            # GET /api/v3/store/customers/me/tax_identifiers
            #
            # Everything the buyer could choose between at checkout. Small and
            # unpaginated by nature — a business has a handful of registrations,
            # not a page of them.
            def index
              render json: { data: serialize_collection(current_user.tax_identifiers.to_a) }
            end

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

            def require_kind!
              return if params[:kind].present?

              render_error(
                code: ERROR_CODES[:parameter_missing],
                message: 'kind is required — name the registration to read, replace or remove',
                status: :unprocessable_content
              )
            end

            def tax_identifier
              @tax_identifier ||= current_user.tax_identifiers.for_kind(params[:kind]).first
            end
          end
        end
      end
    end
  end
end
