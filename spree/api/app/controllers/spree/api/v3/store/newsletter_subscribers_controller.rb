# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Store
        class NewsletterSubscribersController < Store::BaseController
          rate_limit to: Spree::Api::Config[:rate_limit_password_reset],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     only: [:create, :verify],
                     with: RATE_LIMIT_RESPONSE

          # POST /api/v3/store/newsletter_subscribers
          def create
            subscriber = Spree::NewsletterSubscriber.subscribe(
              email: params[:email],
              user: current_user,
              store: current_store
            )

            if subscriber.errors.any?
              render_errors(subscriber.errors)
            else
              render json: { message: Spree.t(:newsletter_subscription_requested, scope: :api) }, status: :accepted
            end
          end

          # GET /api/v3/store/newsletter_subscribers/verify?token=...
          def verify
            token = params[:token].to_s

            return render_invalid_verification_token if token.blank?

            Spree::NewsletterSubscriber.verify(token: token)
            render json: { message: Spree.t(:newsletter_subscription_verified, scope: :api) }
          rescue ActiveRecord::RecordNotFound
            render_invalid_verification_token
          end

          private

          def render_invalid_verification_token
            render_error(
              code: ERROR_CODES[:newsletter_verification_token_invalid],
              message: Spree.t(:newsletter_verification_token_invalid, scope: :api),
              status: :unprocessable_content
            )
          end
        end
      end
    end
  end
end
