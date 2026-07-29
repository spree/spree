module Spree
  module Api
    module V3
      module Store
        module Carts
          class FulfillmentsController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::OrderLock

            before_action :find_cart!

            # GET /api/v3/store/carts/:cart_id/fulfillments
            def index
              fulfillments = @cart.fulfillments.includes(delivery_rates: :delivery_method)
              render json: {
                data: fulfillments.map { |s| Spree.api.fulfillment_serializer.new(s, params: serializer_params).to_h },
                meta: { count: fulfillments.size }
              }
            end

            # PATCH /api/v3/store/carts/:cart_id/fulfillments/:id
            # Selects a delivery rate, and for pickup_point methods a concrete
            # pickup point (validated against the provider, then frozen into
            # pickup_point_data).
            def update
              with_order_lock do
                fulfillment = @cart.fulfillments.find_by_prefix_id!(params[:id])

                if permitted_params[:selected_delivery_rate_id].present?
                  fulfillment.selected_delivery_rate_id = permitted_params[:selected_delivery_rate_id]
                end

                if permitted_params[:pickup_point_external_id].present?
                  return unless assign_pickup_point(fulfillment, permitted_params[:pickup_point_external_id])
                end

                recalculate

                render_cart
              end
            end

            private

            def permitted_params
              params.permit(:selected_delivery_rate_id, :pickup_point_external_id)
            end

            def recalculate
              return if @cart.complete? || @cart.canceled?

              @cart.update_with_updater!
            rescue StandardError => e
              Rails.error.report(e, context: { order_id: @cart.id }, source: 'spree.checkout')
            ensure
              @cart.reload
            end

            # @return [Boolean] false when the response has already been rendered
            def assign_pickup_point(fulfillment, external_id)
              provider = fulfillment.delivery_method&.pickup_point_provider_instance
              if provider.nil?
                render_error(
                  code: ERROR_CODES[:validation_error],
                  message: Spree.t('errors.messages.no_pickup_point_provider'),
                  status: :unprocessable_entity
                )
                return false
              end

              point = provider.find_by_external_id(external_id)
              if point.nil?
                render_error(
                  code: ERROR_CODES[:record_not_found],
                  message: Spree.t('errors.messages.pickup_point_not_found'),
                  status: :not_found
                )
                return false
              end

              fulfillment.update!(pickup_point_data: point.to_pickup_point_data)
              true
            end
          end
        end
      end
    end
  end
end
