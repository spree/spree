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
            def show
              return head :not_found if @cart.tax_identifier.nil?

              render json: serialize_resource(@cart.tax_identifier)
            end

            # PUT /api/v3/store/carts/:cart_id/tax_identifier
            def update
              resource = @cart.tax_identifier || @cart.build_tax_identifier
              resource.assign_attributes(permitted_params)

              if resource.save
                # Tax depends on the registration, so the cart has to be re-costed.
                Spree.cart_recalculate_totals_workflow.call(cart: @cart)
                render json: serialize_resource(resource), status: resource.previously_new_record? ? :created : :ok
              else
                render_validation_error(resource.errors)
              end
            end

            # DELETE /api/v3/store/carts/:cart_id/tax_identifier
            def destroy
              return head :not_found if @cart.tax_identifier.nil?

              @cart.tax_identifier.destroy!
              Spree.cart_recalculate_totals_workflow.call(cart: @cart.reload)
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
