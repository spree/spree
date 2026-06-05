# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::WebhookEndpoint}.
        #
        # Never exposes `secret_key` outside of the create response (encrypted
        # at rest, plaintext only in memory after generation). The full secret
        # is delivered exactly once via {#secret_key} below — `nil` everywhere
        # else.
        class WebhookEndpointSerializer < V3::BaseSerializer
          typelize name: [:string, nullable: true],
                   url: :string,
                   active: :boolean,
                   subscriptions: [:string, multi: true],
                   secret_key: [:string, nullable: true],
                   disabled_at: [:string, nullable: true],
                   disabled_reason: [:string, nullable: true],
                   last_delivery_at: [:string, nullable: true],
                   recent_delivery_count: :number,
                   recent_failure_count: :number,
                   total_delivery_count: :number,
                   successful_delivery_count: :number,
                   failed_delivery_count: :number

          attributes :name, :url, :active, :subscriptions,
                     :disabled_reason,
                     created_at: :iso8601, updated_at: :iso8601,
                     disabled_at: :iso8601

          # Plaintext on the create response only — the model owns the
          # "fresh-from-create" rule via `secret_key_for_response`. Every
          # subsequent read serializes nil.
          attribute :secret_key, &:secret_key_for_response

          attribute :last_delivery_at do |endpoint|
            value = endpoint.webhook_deliveries.maximum(:delivered_at)
            value.respond_to?(:iso8601) ? value.iso8601 : value
          end

          attribute :recent_delivery_count do |endpoint|
            endpoint.webhook_deliveries.where(created_at: 7.days.ago..).count
          end

          attribute :recent_failure_count do |endpoint|
            endpoint.webhook_deliveries.where(created_at: 7.days.ago.., success: false).count
          end

          # Lifetime totals — back the health summary panel on the endpoint
          # detail sheet (success % over all deliveries, like the legacy admin's
          # `_summary.html.erb`).
          attribute :total_delivery_count do |endpoint|
            endpoint.webhook_deliveries.count
          end

          attribute :successful_delivery_count do |endpoint|
            endpoint.webhook_deliveries.successful.count
          end

          attribute :failed_delivery_count do |endpoint|
            endpoint.webhook_deliveries.failed.count
          end
        end
      end
    end
  end
end
