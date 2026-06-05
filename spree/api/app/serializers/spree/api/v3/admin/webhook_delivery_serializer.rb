# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::WebhookDelivery}.
        #
        # Surface the delivery log so admins can audit + retry failed webhook
        # attempts. Includes the request payload + response body so they can
        # inspect what was sent and what the endpoint returned.
        class WebhookDeliverySerializer < V3::BaseSerializer
          typelize event_name: :string,
                   event_id: [:string, nullable: true],
                   response_code: [:number, nullable: true],
                   execution_time: [:number, nullable: true],
                   error_type: [:string, nullable: true],
                   request_errors: [:string, nullable: true],
                   response_body: [:string, nullable: true],
                   success: [:boolean, nullable: true],
                   delivered_at: [:string, nullable: true],
                   payload: 'Record<string, unknown>',
                   webhook_endpoint_id: :string,
                   webhook_endpoint_url: :string

          attributes :event_name, :event_id, :response_code, :execution_time,
                     :error_type, :request_errors, :response_body, :success,
                     :payload,
                     created_at: :iso8601, updated_at: :iso8601,
                     delivered_at: :iso8601

          attribute :webhook_endpoint_id do |delivery|
            delivery.webhook_endpoint&.prefixed_id
          end

          # Delegated from the parent endpoint — saves callers from having to
          # join the endpoint payload to show "where did this delivery go?".
          attribute :webhook_endpoint_url do |delivery|
            delivery.webhook_endpoint&.url
          end
        end
      end
    end
  end
end
