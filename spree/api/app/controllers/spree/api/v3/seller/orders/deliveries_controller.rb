module Spree
  module Api
    module V3
      module Seller
        module Orders
          # The consignments on a parcel the seller ships themselves. Rooted
          # at the order fetched through `current_seller_orders`, so a
          # fulfillment on somebody else's order reads as missing.
          class DeliveriesController < Seller::BaseController
            include Spree::Api::V3::OrderLock

            scoped_resource :fulfillments

            before_action :set_fulfillment
            before_action :set_delivery, only: [:show, :update, :destroy]

            def index
              render json: { data: @fulfillment.deliveries.map { |delivery| serialize(delivery) } }
            end

            def show
              render json: serialize(@delivery)
            end

            # POST /api/v3/seller/orders/:order_id/fulfillments/:fulfillment_id/deliveries
            def create
              authorize! :update, @fulfillment

              with_order_lock do
                result = Spree.delivery_create_service.call(
                  owner: @fulfillment,
                  tracking_number: delivery_params[:tracking_number],
                  carrier: delivery_params[:carrier],
                  service: delivery_params[:service],
                  tracking_url: delivery_params[:tracking_url]
                )

                if result.success?
                  render json: serialize(result.value), status: :created
                else
                  render_result_error(result)
                end
              end
            end

            # PATCH .../deliveries/:id
            def update
              authorize! :update, @fulfillment

              with_order_lock do
                attributes = delivery_params.to_h
                if attributes[:tracking_number].present? && attributes[:tracking_number].squish != @delivery.tracking_number
                  attributes[:status] = 'pending'
                end

                if @delivery.update(attributes)
                  render json: serialize(@delivery.reload)
                else
                  render_validation_error(@delivery.errors)
                end
              end
            end

            # DELETE .../deliveries/:id — 422 when a label minted it.
            def destroy
              authorize! :update, @fulfillment

              with_order_lock do
                result = Spree.delivery_destroy_service.call(delivery: @delivery)

                if result.success?
                  head :no_content
                else
                  render_result_error(result)
                end
              end
            end

            protected

            def read_actions
              %w[index show]
            end

            private

            def set_fulfillment
              @order = current_seller_orders.find_by_prefix_id!(params[:order_id])
              authorize! :show, @order
              @fulfillment = @order.fulfillments.find_by_prefix_id!(params[:fulfillment_id])
            end

            def set_delivery
              @delivery = @fulfillment.deliveries.find_by_prefix_id!(params[:id])
            end

            def delivery_params
              @delivery_params ||= params.permit(:tracking_number, :carrier, :service, :tracking_url)
            end

            def serialize(delivery)
              Spree.api.seller_delivery_serializer.new(delivery, params: { store: current_store }).to_h
            end
          end
        end
      end
    end
  end
end
