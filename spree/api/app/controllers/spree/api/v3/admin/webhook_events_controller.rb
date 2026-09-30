module Spree
  module Api
    module V3
      module Admin
        # The events a webhook endpoint can subscribe to — every event Spree
        # and the installed extensions declare, so the endpoint picker never
        # drifts from what the server really publishes.
        class WebhookEventsController < Admin::BaseController
          scoped_resource :webhooks

          # GET /api/v3/admin/webhook_events
          def index
            authorize!(:show, Spree::WebhookEndpoint)
            entries = Spree::Events.catalog.webhook_events

            render json: {
              data: entries.map { |entry| Spree.api.admin_webhook_event_serializer.new(entry).to_h },
              meta: { count: entries.size }
            }
          end
        end
      end
    end
  end
end
