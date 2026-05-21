# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Store
        class NewsletterSubscribersController < Store::BaseController
          rate_limit to: Spree::Api::Config[:rate_limit_password_reset],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     only: :create,
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
        end
      end
    end
  end
end
