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
              fulfillments = @cart.shipments.includes(shipping_rates: :shipping_method)
              render json: {
                data: fulfillments.map { |s| Spree.api.fulfillment_serializer.new(s, params: serializer_params).to_h },
                meta: { count: fulfillments.size }
              }
            end

            # PATCH /api/v3/store/carts/:cart_id/fulfillments/:id
            # Select a delivery rate for a specific fulfillment
            def update
              with_order_lock do
                fulfillment = @cart.shipments.find_by_prefix_id!(params[:id])

                if permitted_params[:selected_delivery_rate_id].present?
                  delivery_rate = fulfillment.shipping_rates.find_by_prefix_id!(permitted_params[:selected_delivery_rate_id])
                  fulfillment.selected_shipping_rate_id = delivery_rate.id
                  fulfillment.save!
                end

                # Auto-advance (e.g. delivery → payment) after rate selection.
                # Temporary — Spree 6 removes the checkout state machine.
                try_advance

                render_cart
              end
            end

            private

            def permitted_params
              params.permit(:selected_delivery_rate_id)
            end

            # Temporary — Spree 6 removes the checkout state machine.
            def try_advance
              return if @cart.confirm? || @cart.complete? || @cart.canceled?

              loop do
                break if @cart.payment?
                break unless @cart.next
              end
            rescue StandardError => e
              Rails.error.report(e, context: { order_id: @cart.id, state: @cart.state }, source: 'spree.checkout')
            ensure
              @cart.reload
            end
          end
        end
      end
    end
  end
end
