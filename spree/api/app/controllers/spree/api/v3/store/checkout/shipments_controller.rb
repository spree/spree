module Spree
  module Api
    module V3
      module Store
        module Checkout
          class ShipmentsController < Store::BaseController
            include Spree::Api::V3::CartResolvable
            include Spree::Api::V3::OrderLock

            before_action :find_cart!

            # GET /api/v3/store/checkout/shipments
            def index
              shipments = @cart.shipments.includes(shipping_rates: :shipping_method)
              render json: {
                data: shipments.map { |s| Spree.api.shipment_serializer.new(s, params: serializer_params).to_h },
                meta: { count: shipments.size }
              }
            end

            # PATCH /api/v3/store/checkout/shipments/:id
            # Select a shipping rate for a specific shipment
            def update
              with_order_lock do
                shipment = @cart.shipments.find_by_prefix_id!(params[:id])

                if permitted_params[:selected_shipping_rate_id].present?
                  shipping_rate = shipment.shipping_rates.find_by_prefix_id!(permitted_params[:selected_shipping_rate_id])
                  shipment.selected_shipping_rate_id = shipping_rate.id
                  shipment.save!
                end

                # Auto-advance (e.g. delivery → payment) after rate selection.
                # Temporary — Spree 6 removes the checkout state machine.
                try_advance

                render_cart
              end
            end

            private

            def permitted_params
              params.permit(:selected_shipping_rate_id)
            end

            # Temporary — Spree 6 removes the checkout state machine.
            def try_advance
              return if @cart.complete? || @cart.canceled?

              loop do
                break unless @cart.next
                break if @cart.confirm? || @cart.complete?
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
