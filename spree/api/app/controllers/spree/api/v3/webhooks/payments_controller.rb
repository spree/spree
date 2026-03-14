module Spree
  module Api
    module V3
      module Webhooks
        class PaymentsController < ActionController::API
          include ActionController::RateLimiting

          RATE_LIMIT_RESPONSE = -> {
            [429, { 'Content-Type' => 'application/json', 'Retry-After' => '60' },
             [{ error: { code: 'rate_limit_exceeded', message: 'Too many requests' } }.to_json]]
          }

          rate_limit to: 120, within: 1.minute,
                     store: Rails.cache,
                     by: -> { request.remote_ip },
                     with: RATE_LIMIT_RESPONSE

          # POST /api/v3/webhooks/payments/:payment_method_id
          #
          # Verifies the webhook signature synchronously (returns 401 if invalid),
          # then enqueues async processing and returns 200 immediately.
          def create
            payment_method = Spree::PaymentMethod.find_by_prefix_id!(params[:payment_method_id])

            # Signature verification must be synchronous — invalid = 401
            result = payment_method.parse_webhook_event(request.raw_post, request.headers)

            # Unsupported event — acknowledge receipt
            return head :ok if result.nil?

            # Process asynchronously — gateways have timeout limits and will
            # retry on timeouts, so we must return 200 quickly.
            Spree::Payments::HandleWebhookJob.perform_later(
              payment_method_id: payment_method.id,
              action: result[:action].to_s,
              payment_session_id: result[:payment_session].id
            )

            head :ok
          rescue Spree::PaymentMethod::WebhookSignatureError
            head :unauthorized
          rescue ActiveRecord::RecordNotFound
            head :not_found
          rescue StandardError => e
            Rails.error.report(e, source: 'spree.webhooks.payments')
            head :ok
          end
        end
      end
    end
  end
end
