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

          # Must render — instance_exec'd in a before_action, where only
          # render/redirect halts the chain.
          RATE_LIMIT_RESPONSE = -> {
            response.headers['Retry-After'] = '60'
            render json: { error: { code: 'rate_limit_exceeded', message: 'Too many requests' } },
                   status: :too_many_requests
          }

          rate_limit to: 120, within: 1.minute,
                     store: Rails.cache,
                     by: -> { request.remote_ip },
                     with: RATE_LIMIT_RESPONSE

          def create
            integration = current_store.integrations.active.find_by_prefix_id!(params[:integration_id])

            event = integration.parse_webhook_event(request.raw_post, request.headers)
            return head :ok if event.nil?

            delivery = find_delivery(event[:tracking_code])
            return head :ok if delivery.nil?

            Spree.delivery_update_tracking_workflow.call(
              delivery: delivery,
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
          # consignments whose parcel was not canceled, so a recycled code
          # cannot reopen an old one. The newest wins when a code was reused.
          # Carriers reuse tracking numbers across years, so a code can match
          # more than one consignment. The store-scoped index makes that
          # candidate set tiny — almost always one row — and the stood-down
          # ones are dropped from it rather than from every parcel in the
          # database. The newest survivor wins.
          CANDIDATE_LIMIT = 20

          def find_delivery(tracking_code)
            return if tracking_code.blank?

            current_store.deliveries.
              where(tracking_number: tracking_code).
              order(created_at: :desc, id: :desc).
              limit(CANDIDATE_LIMIT).
              includes(:owner).
              find { |delivery| delivery.owner.present? && !delivery.owner.canceled? }
          end
        end
      end
    end
  end
end
