module Spree
  module Api
    module V3
      module Webhooks
        # Marketplace events about sellers: POST /api/v3/webhooks/payouts/:payment_method_id.
        #
        # Separate from the payments endpoint because providers scope the two
        # separately. Events originating in a seller's own account — whether
        # they may be paid, whether a payout reached their bank — arrive on
        # their own subscription with their own signing secret, so verifying
        # them against the payment endpoint's secret would reject every one.
        #
        # Addressed to the payment method because a marketplace pays sellers
        # out of the account it charges their customers from: the same
        # credentials, and so the same record.
        #
        # Handled inline rather than handed to a job, like the carrier
        # endpoint: marking a seller payable or a payout settled is a couple of
        # database writes, well inside any sender's timeout.
        class PayoutsController < ActionController::API
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
            payment_method = current_store.payment_methods.find_by_prefix_id!(params[:payment_method_id])
            return head :not_found unless payment_method.respond_to?(:handle_payout_webhook)

            payment_method.handle_payout_webhook(request.raw_post, request.headers)

            head :ok
          rescue Spree::PaymentMethod::WebhookSignatureError
            head :unauthorized
          rescue ActiveRecord::RecordNotFound
            head :not_found
          rescue StandardError => e
            Rails.error.report(e, source: 'spree.webhooks.payouts')
            head :ok
          end
        end
      end
    end
  end
end
