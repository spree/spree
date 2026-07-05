module Spree
  module Api
    module V3
      module Admin
        # Nested under WebhookEndpoint — deliveries are always read in the
        # context of their endpoint (the delivery log on the endpoint detail
        # page) and never accessed by ID at the top level.
        class WebhookDeliveriesController < ResourceController
          scoped_resource :webhooks

          # POST /api/v3/admin/webhook_endpoints/:webhook_endpoint_id/deliveries/:id/redeliver
          #
          # Creates a new delivery row with the same payload + event_name and
          # queues it. The original row is preserved for audit history.
          #
          # @return [Hash] the serialized newly-queued {Spree::WebhookDelivery},
          #   HTTP 201.
          def redeliver
            @resource = find_resource
            authorize!(:update, webhook_endpoint)

            new_delivery = @resource.redeliver!
            render json: serialize_resource(new_delivery), status: :created
          end

          protected

          def model_class
            Spree::WebhookDelivery
          end

          def serializer_class
            Spree.api.admin_webhook_delivery_serializer
          end

          def scope
            webhook_endpoint.webhook_deliveries.recent
          end

          def webhook_endpoint
            @webhook_endpoint ||= current_store.webhook_endpoints.find_by_prefix_id!(
              params[:webhook_endpoint_id]
            )
          end
        end
      end
    end
  end
end
