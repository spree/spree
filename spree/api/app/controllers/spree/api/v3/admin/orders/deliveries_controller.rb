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

            # The permit list itself lives in DeliveryActions, shared with the
            # seller branch; this declaration documents it.
            request_params :delivery do
              string :tracking_number, required: :create,
                                       description: 'A carrier tracking number, a freight PRO or container number, or a full tracking link. A corrected number resets the carrier status to `pending`.'
              string :carrier, description: "Free text; detected from the number's format when omitted."
              string :service, :tracking_url
            end

            request_params 'DeliveryMarkDeliveredParams', action: :mark_delivered do
              datetime :delivered_at, description: 'When it arrived. Defaults to now.'
              boolean :notify_customer,
                      description: 'Whether the customer gets a delivery notification once the parcel completes. Defaults to true.'
            end

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

                render_result(result)
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
              @mark_delivered_params ||= params.permit(*declared_permitted_attributes)
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
