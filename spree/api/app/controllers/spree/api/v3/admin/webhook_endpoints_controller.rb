module Spree
  module Api
    module V3
      module Admin
        # Admin API for outbound webhook endpoints — CRUD plus the three
        # endpoint-scoped actions the legacy admin had (send_test, enable,
        # disable).
        class WebhookEndpointsController < ResourceController
          scoped_resource :webhooks

          before_action :reject_unauthorized_credential_subscription!, only: [:create, :update]

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
            params.permit(*model_additional_permitted_attributes, :name, :url, :active, subscriptions: [])
          end

          private

          # Customer password reset tokens are account credentials, so the
          # webhooks permission alone cannot subscribe an endpoint to them, or
          # repoint an endpoint that already receives them.
          def reject_unauthorized_credential_subscription!
            return if holds_permission?('write_customers')

            requested = Array(permitted_params[:subscriptions]) & Spree::WebhookEndpoint::CREDENTIAL_EVENTS
            return if requested.empty? && !repoints_credential_endpoint?

            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
              message: "Receiving #{Spree::WebhookEndpoint::CREDENTIAL_EVENTS.to_sentence} requires permission to manage customers",
              status: :forbidden
            )
          end

          def repoints_credential_endpoint?
            return false unless action_name == 'update'
            return false unless permitted_params.key?(:url) || permitted_params.key?(:subscriptions)

            current_store.webhook_endpoints.find_by_prefix_id(params[:id])&.receives_credentials?
          end
        end
      end
    end
  end
end
