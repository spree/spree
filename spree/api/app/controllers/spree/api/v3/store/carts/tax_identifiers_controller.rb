module Spree
  module Api
    module V3
      module Store
        module Carts
          # A registration entered during checkout, overriding whatever the
          # customer's profile holds — the buyer paying through a different
          # company than the one on their account.
          class TaxIdentifiersController < Store::BaseController
            include Spree::Api::V3::CartResolvable

            before_action :find_cart!

            # GET /api/v3/store/carts/:cart_id/tax_identifier
            #
            # The registration this cart will be taxed against — the override
            # when one was entered, the customer's own otherwise. A checkout page
            # asking what applies wants the answer the provider will get, not
            # whether an override happens to exist.
            def show
              resolved = @cart.resolved_tax_identifier
              return head :not_found if resolved.nil?

              render json: serialize_resource(resolved)
            end

            # PUT /api/v3/store/carts/:cart_id/tax_identifier
            def update
              resource = @cart.tax_identifier || @cart.build_tax_identifier
              resource.assign_attributes(permitted_params)

              if resource.save
                # Tax depends on the registration, so the cart has to be re-costed.
                @cart.recalculate_totals!
                render json: serialize_resource(resource), status: resource.previously_new_record? ? :created : :ok
              else
                render_validation_error(resource.errors)
              end
            end

            # DELETE /api/v3/store/carts/:cart_id/tax_identifier
            #
            # Clears the override only. The customer's own registration is theirs
            # to remove from their profile — a cleared checkout field must not
            # delete it — so a cart with no override of its own reports nothing
            # to delete even when GET returns an inherited one.
            def destroy
              return head :not_found if @cart.tax_identifier.nil?

              @cart.tax_identifier.destroy!
              @cart.reload.recalculate_totals!
              head :no_content
            end

            protected

            def serializer_class
              Spree.api.tax_identifier_serializer
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
