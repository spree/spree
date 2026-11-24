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
            # The whole catalog on one page unless the caller asks for less:
            # clients list every event to build a picker.
            catalog = Spree::Events.catalog.webhook_events
            @pagy, entries = pagy(:offset, catalog, limit: [catalog.size, 1].max)

            render json: {
              data: entries.map { |entry| serializer_class.new(entry).to_h },
              meta: collection_meta(entries)
            }
          end

          private

          def serializer_class
            Spree.api.admin_webhook_event_serializer
          end
        end
      end
    end
  end
end
