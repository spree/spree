module Spree
  module Api
    module V3
      module Store
        class NewsletterSubscribersController < Store::BaseController
          allow_guest_storefront_access!
          rate_limit to: Spree::Api::Config[:rate_limit_register],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     only: [:create, :verify, :destroy, :request_unsubscribe, :index],
                     with: RATE_LIMIT_RESPONSE

          prepend_before_action :require_authentication!, only: [:index]

          # GET /api/v3/store/newsletter_subscribers
          def index
            subscribers = Spree::NewsletterSubscriber.
                            for_store(current_store).
                            accessible_by(current_ability, :show)

            render json: serialize_collection(subscribers)
          end

          # POST /api/v3/store/newsletter_subscribers
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

          # DELETE /api/v3/store/newsletter_subscribers/:id
          # Accepts either of:
          #   - Authorization: Bearer <jwt> — logged-in customer destroying their own subscription
          #   - ?token=<unsubscribe-token>  — bearer from `subscriber.generate_token_for(:unsubscribe)`,
          #                                   typically clicked from an unsubscribe email
          def destroy
            subscriber = find_owned_subscriber || find_subscriber_by_unsubscribe_token

            if subscriber.blank?
              return render_error(
                code: ERROR_CODES[:invalid_token],
                message: Spree.t(:newsletter_unsubscribe_token_invalid, scope: :api),
                status: :unprocessable_content
              )
            end

            linked_user = subscriber.user
            subscriber.destroy!

            # Keep accepts_email_marketing in sync, but only when no subscriptions remain.
            if linked_user&.accepts_email_marketing? && Spree::NewsletterSubscriber.where(user_id: linked_user.id).none?
              linked_user.update(accepts_email_marketing: false)
            end

            head :no_content
          end

          # POST /api/v3/store/newsletter_subscribers/request_unsubscribe
          # Publishes a `newsletter_subscriber.unsubscribe_requested` event carrying the unsubscribe token.
          # Always returns 202 to prevent email enumeration.
          def request_unsubscribe
            subscriber = Spree::NewsletterSubscriber.for_store(current_store).find_by(email: params[:email])

            if subscriber
              payload = {
                id: subscriber.prefixed_id,
                email: subscriber.email,
                unsubscribe_token: subscriber.generate_token_for(:unsubscribe),
                store_id: current_store.prefixed_id,
                customer_id: subscriber.user&.prefixed_id
              }

              redirect_url = validated_redirect_url
              payload[:redirect_url] = redirect_url if redirect_url.present?

              subscriber.publish_event('newsletter_subscriber.unsubscribe_requested', payload)
            end

            head :accepted
          end

          protected

          def serializer_class
            Spree::Api::V3::NewsletterSubscriberSerializer
          end

          private

          def find_owned_subscriber
            return unless current_user

            Spree::NewsletterSubscriber.
              for_store(current_store).
              accessible_by(current_ability, :destroy).
              find_by_prefix_id(params[:id])
          end

          def find_subscriber_by_unsubscribe_token
            return if params[:token].blank?

            subscriber = Spree::NewsletterSubscriber.for_store(current_store).find_by_token_for(:unsubscribe, params[:token])
            subscriber if subscriber&.prefixed_id == params[:id]
          end

          # Drop redirect_url when it isn't in the store's allow-list — secure-by-default,
          # mirrors password_resets. Returning nil omits it from the webhook payload rather
          # than rejecting the request, so callers can't probe the allow-list via 4xx errors.
          def validated_redirect_url
            redirect_url = params[:redirect_url]
            return nil if redirect_url.blank?
            return nil unless current_store.allowed_origin?(redirect_url)

            redirect_url
          end
        end
      end
    end
  end
end
