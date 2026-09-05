module Spree
  module Api
    module V3
      module Admin
        module Orders
          # The consignments of one fulfillment, under
          # /orders/:order_id/fulfillments/:fulfillment_id/deliveries.
          #
          # CRUD lives in the shared concern; what is here is the store-wide
          # scope and the one action only an operator has. The
          # fulfillment-level mark_delivered stays beside it for parcels that
          # have no delivery row at all.
          class DeliveriesController < BaseController
            include Spree::Api::V3::Orders::DeliveryActions

            before_action :set_resource, only: [:show, :update, :destroy, :mark_delivered]

            # PATCH .../deliveries/:id/mark_delivered — staff saying this one
            # consignment arrived; the fulfillment follows once every
            # consignment has.
            def mark_delivered
              with_order_lock do
                result = Spree.delivery_update_tracking_workflow.call(
                  delivery: @resource,
                  tracking_status: 'delivered',
                  delivered_at: mark_delivered_params[:delivered_at],
                  notify_customer: notify_customer?(mark_delivered_params[:notify_customer])
                )

                if result.success?
                  render json: serialize_resource(result.value)
                else
                  render_result_error(result)
                end
              end
            end

            protected

            def serializer_class
              Spree.api.admin_delivery_serializer
            end

            # The consignments hang off the fulfillment, not the order, so
            # the parent is narrowed one step past the base's.
            def set_parent
              super
              @parent = @order.fulfillments.find_by_prefix_id!(params[:fulfillment_id])
            end

            private

            def mark_delivered_params
              @mark_delivered_params ||= params.permit(:delivered_at, :notify_customer)
            end

            # Only an explicit false suppresses the email.
            def notify_customer?(value)
              !ActiveModel::Type::Boolean.new.cast(value).equal?(false)
            end
          end
        end
      end
    end
  end
end
