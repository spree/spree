module Spree
  module Api
    module V3
      module Webhooks
        # Carrier webhooks, addressed to the integration holding the carrier's
        # credentials: POST /api/v3/webhooks/fulfillments/:integration_id.
        #
        # Mirrors the payments webhook endpoint: the integration verifies the
        # signature synchronously (401 when it fails, so a misconfigured
        # sender notices), translates the payload into core vocabulary, and
        # anything unrecognised is acknowledged with 200 — carriers retry
        # anything else, and there is nothing to retry for a parcel that is
        # not ours. Unlike payments there is no job hand-off: recording a
        # tracking update is a couple of database writes, well inside any
        # sender's timeout.
        class FulfillmentsController < ActionController::API
          include ActionController::RateLimiting
          include Spree::Core::ControllerHelpers::Store

          RATE_LIMIT_RESPONSE = -> {
            [429, { 'Content-Type' => 'application/json', 'Retry-After' => '60' },
             [{ error: { code: 'rate_limit_exceeded', message: 'Too many requests' } }.to_json]]
          }

          rate_limit to: 120, within: 1.minute,
                     store: Rails.cache,
                     by: -> { request.remote_ip },
                     with: RATE_LIMIT_RESPONSE

          def create
            integration = current_store.integrations.active.find_by_prefix_id!(params[:integration_id])

            event = integration.parse_webhook_event(request.raw_post, request.headers)
            return head :ok if event.nil?

            fulfillment = find_fulfillment(event[:tracking_code])
            return head :ok if fulfillment.nil?

            Spree.fulfillment_update_tracking_workflow.call(
              fulfillment: fulfillment,
              **event.except(:tracking_code)
            )

            head :ok
          rescue Spree::Integration::WebhookSignatureError
            head :unauthorized
          rescue ActiveRecord::RecordNotFound
            head :not_found
          rescue StandardError => e
            Rails.error.report(e, source: 'spree.webhooks.fulfillments')
            head :ok
          end

          private

          # Scoped to the store the verified integration belongs to — a
          # tracking code can never address another tenant's parcel — and to
          # parcels that shipped, so a recycled code cannot reopen an old one.
          def find_fulfillment(tracking_code)
            return if tracking_code.blank?

            Spree::Fulfillment.
              joins(:order).merge(current_store.orders).
              where(tracking: tracking_code).
              not_canceled.
              reverse_chronological.
              first
          end
        end
      end
    end
  end
end
