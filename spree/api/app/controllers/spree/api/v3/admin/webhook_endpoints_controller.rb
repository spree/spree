module Spree
  module Api
    module V3
      module Admin
        # Admin API for outbound webhook endpoints — CRUD plus the three
        # endpoint-scoped actions the legacy admin had (send_test, enable,
        # disable).
        class WebhookEndpointsController < ResourceController
          scoped_resource :settings

          # POST /api/v3/admin/webhook_endpoints/:id/send_test
          #
          # Fires a synthetic `webhook.test` delivery so admins can verify the
          # endpoint is reachable + their signature-verification code works.
          #
          # @return [Hash] the serialized {Spree::WebhookDelivery}, HTTP 201.
          def send_test
            @resource = find_resource
            authorize!(:update, @resource)

            delivery = @resource.send_test!
            render json: Spree.api.admin_webhook_delivery_serializer.new(delivery).to_h, status: :created
          end

          # PATCH /api/v3/admin/webhook_endpoints/:id/enable
          #
          # Re-enables an endpoint that was auto-disabled after repeated failures.
          #
          # @return [Hash] the serialized {Spree::WebhookEndpoint}.
          def enable
            @resource = find_resource
            authorize!(:update, @resource)

            @resource.enable!
            render json: serialize_resource(@resource)
          end

          # PATCH /api/v3/admin/webhook_endpoints/:id/disable
          #
          # Manual disable — separate from the auto-disable threshold so the
          # caller can pause an endpoint without waiting for failures.
          #
          # @param reason [String] optional human-readable reason; defaults to
          #   `"Manually disabled"` when blank.
          # @return [Hash] the serialized {Spree::WebhookEndpoint}.
          def disable
            @resource = find_resource
            authorize!(:update, @resource)

            @resource.disable!(reason: params[:reason].presence || 'Manually disabled', notify: false)
            render json: serialize_resource(@resource)
          end

          protected

          def model_class
            Spree::WebhookEndpoint
          end

          def serializer_class
            Spree.api.admin_webhook_endpoint_serializer
          end

          def scope
            current_store.webhook_endpoints.accessible_by(current_ability, :show)
          end

          def permitted_params
            params.permit(:name, :url, :active, subscriptions: [])
          end
        end
      end
    end
  end
end
