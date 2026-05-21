module Spree
  module Api
    module V3
      module Store
        class NewsletterSubscribersController < Store::BaseController
          rate_limit to: Spree::Api::Config[:rate_limit_register],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     only: [:create, :verify],
                     with: RATE_LIMIT_RESPONSE

          # Authentication is optional — the parent's `before_action :authenticate_user`
          # leaves `current_user` nil when no JWT is present, which is the guest path.
          # When a JWT *is* present, we use it to link the subscription to the customer
          # (and auto-verify if the email matches).

          # POST /api/v3/store/newsletter_subscribers
          # Subscribes a guest or authenticated customer to the newsletter for the current store.
          # If the email already has a verified subscription, returns the existing record.
          # If a JWT is provided, the subscription is linked to that customer; if the customer's
          # email matches the subscribed email, the subscription is auto-verified.
          #
          # The optional `redirect_url` is the storefront page that should receive the
          # verification token (e.g. `https://your-store.com/newsletter/confirm`). When
          # provided, it is validated against the store's allowed origins and forwarded
          # in the `newsletter_subscriber.subscription_requested` event so the storefront
          # webhook handler can build the confirmation email link as
          # `redirect_url?token=<verification_token>`.
          def create
            subscriber = Spree::NewsletterSubscriber.subscribe(
              email: params[:email],
              user: current_user,
              store: current_store,
              redirect_url: validated_redirect_url
            )

            if subscriber.errors.any?
              render_errors(subscriber.errors)
            else
              render json: serialize_resource(subscriber), status: :created
            end
          end

          # POST /api/v3/store/newsletter_subscribers/verify
          # Confirms a newsletter subscription using the verification token sent by email.
          # Accepts: { "token": "..." }
          def verify
            token = params[:token]

            if token.blank?
              return render_error(
                code: ERROR_CODES[:parameter_missing],
                message: 'token is required',
                status: :unprocessable_content
              )
            end

            subscriber = Spree::NewsletterSubscriber.for_store(current_store).unverified.find_by(verification_token: token)

            unless subscriber
              return render_error(
                code: ERROR_CODES[:invalid_token],
                message: Spree.t(:newsletter_verification_token_invalid, scope: :api),
                status: :unprocessable_content
              )
            end

            Spree::Newsletter::Verify.new(subscriber: subscriber).call

            render json: serialize_resource(subscriber)
          end

          protected

          def serializer_class
            Spree::Api::V3::NewsletterSubscriberSerializer
          end

          private

          # Validates the requested redirect_url against the current store's allowed
          # origins. Returns nil (the link will be dropped from the event) when the URL
          # is not in the allow-list — same secure-by-default behavior as password resets.
          def validated_redirect_url
            redirect_url = params[:redirect_url]
            return nil if redirect_url.blank?
            return nil unless current_store.allowed_origins.exists?
            return nil unless current_store.allowed_origin?(redirect_url)

            redirect_url
          end
        end
      end
    end
  end
end
