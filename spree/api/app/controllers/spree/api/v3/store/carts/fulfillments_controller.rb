module Spree
  module Api
    module V3
      module Store
        module Carts
          class FulfillmentsController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::OrderLock

            before_action :find_cart!

            request_params 'UpdateFulfillmentParams', action: :update do
              id :selected_delivery_rate_id, example: 'dr_abc123', description: 'The delivery rate to select.'
              string :pickup_point_external_id,
                     description: "For a pickup point delivery method: the provider's id of the point to collect from."
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

                sweep_unavailable_coupon_code!
                render_cart
              end
            end

            private

            def permitted_params
              params.permit(*declared_permitted_attributes)
            end

            def recalculate
              return if @cart.complete?

              @cart.recalculate_totals!
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
                  message: I18n.t('spree.errors.messages.no_pickup_point_provider'),
                  status: :unprocessable_content
                )
                return false
              end

              point = provider.find_by_external_id(external_id)
              if point.nil?
                render_error(
                  code: ERROR_CODES[:record_not_found],
                  message: I18n.t('spree.errors.messages.pickup_point_not_found'),
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
