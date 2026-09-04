module Spree
  module Api
    module V3
      module Admin
        module Orders
          # The consignments of one fulfillment — a parcel each, or a freight
          # PRO number covering several pallets — under
          # /orders/:order_id/fulfillments/:fulfillment_id/deliveries.
          #
          # A delivery is born when a tracking number is attached, days before
          # anything arrives, so POST means "this fulfillment went out as
          # another consignment"; arrival is the mark_delivered transition on
          # an existing row. The fulfillment-level mark_delivered stays beside
          # it for parcels that have no delivery row at all.
          class DeliveriesController < BaseController
            before_action :set_resource, only: [:show, :update, :destroy, :mark_delivered]

            # POST .../deliveries
            def create
              authorize!(:create, Spree::Delivery)

              with_order_lock do
                result = Spree.delivery_create_service.call(owner: @parent, **create_arguments)

                if result.success?
                  render json: serialize_resource(result.value), status: :created
                else
                  render_result_error(result)
                end
              end
            end

            # PATCH .../deliveries/:id — correcting the number, carrier or link.
            # A corrected number is a different parcel to the carrier, so its
            # journey starts over.
            def update
              with_order_lock do
                if @resource.update(@resource.correction_attributes(update_params.to_h))
                  recalculate_delivery
                  render json: serialize_resource(@resource.reload)
                else
                  render_validation_error(@resource.errors)
                end
              end
            end

            # DELETE .../deliveries/:id — 422 when a label minted it.
            def destroy
              with_order_lock do
                result = Spree.delivery_destroy_service.call(delivery: @resource)

                if result.success?
                  head :no_content
                else
                  render_result_error(result)
                end
              end
            end

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

            # A corrected number is a different parcel as far as the carrier
            # is concerned: its journey starts over, and the carrier and link
            # that belonged to the old number go with it unless this request
            # supplies new ones.
            # A consignment that started over may have been the one holding
            # the fulfillment at delivered.
            def recalculate_delivery
              return unless @parent.is_a?(Spree::Fulfillment)

              Spree.fulfillment_recalculate_delivery_service.call(fulfillment: @parent)
            end

            def model_class
              Spree::Delivery
            end

            def serializer_class
              Spree.api.admin_delivery_serializer
            end

            def parent_association
              :deliveries
            end

            def collection_includes
              [:shipping_label]
            end

            def set_parent
              @order = current_store.orders.find_by_prefix_id!(params[:order_id])
              @parent = @order.fulfillments.find_by_prefix_id!(params[:fulfillment_id])
            end

            def resource_permitted_attributes
              [:tracking_number, :carrier, :service, :tracking_url]
            end

            def update_params
              params.permit(*resource_permitted_attributes)
            end

            def create_arguments
              permitted = params.permit(*resource_permitted_attributes)
              {
                tracking_number: permitted[:tracking_number],
                carrier: permitted[:carrier],
                service: permitted[:service],
                tracking_url: permitted[:tracking_url]
              }
            end

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
