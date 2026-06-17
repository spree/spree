module Spree
  module Api
    module V3
      module Admin
        module Orders
          class StoreCreditsController < BaseController
            skip_before_action :set_resource, raise: false

            # POST /api/v3/admin/orders/:order_id/store_credits
            #
            # Body: { amount: Number (optional) }
            #
            # When `amount` is omitted, applies the customer's available store
            # credit up to the order total.
            def create
              with_order_lock do
                result = Spree.checkout_add_store_credit_service.call(
                  order: @parent,
                  amount: params[:amount].try(:to_f)
                )

                if result.success?
                  render json: serialize_resource(result.value), status: :created
                else
                  render_service_error(result.error)
                end
              end
            end

            # DELETE /api/v3/admin/orders/:order_id/store_credits
            def destroy
              with_order_lock do
                result = Spree.checkout_remove_store_credit_service.call(order: @parent)

                if result.success?
                  head :no_content
                else
                  render_service_error(result.error)
                end
              end
            end

            protected

            def model_class
              Spree::Order
            end

            def serializer_class
              Spree.api.admin_order_serializer
            end
          end
        end
      end
    end
  end
end
