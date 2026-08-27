# frozen_string_literal: true

module Spree
  module Api
    module V3
      module Seller
        # Password reset for the marketplace seller panel.
        #
        # Parallel to the admin controller rather than a subclass of it, per
        # Decision 10: what differs is the audience it issues and the panel the
        # emailed link opens, and both are the point. A seller resetting their
        # password must end up with a seller session on the seller panel, never
        # an admin one on the dashboard.
        class PasswordResetsController < Spree::Api::V3::BaseController
          include Spree::Api::V3::Seller::AuthCookies
          include Spree::Api::V3::JwtAuthentication

          # No `skip_scope_check!`: this extends the plain v3 base, which has
          # no authentication or scope gate to lift. The emailed token is the
          # only credential, exactly as on the admin twin.
          rate_limit to: Spree::Api::Config[:rate_limit_password_reset],
                     within: Spree::Api::Config[:rate_limit_window].seconds,
                     store: Rails.cache,
                     with: RATE_LIMIT_RESPONSE

          # POST /api/v3/seller/auth/password_resets
          def create
            user = Spree.admin_user_class.find_by(email: params[:email])

            # Staff share this user class, so a match is not enough: a store
            # admin who runs no seller has no panel to be sent to, and mailing
            # them a seller reset link would be an invitation to a session they
            # cannot hold.
            if user&.seller_member?
              user.publish_event('seller_user.password_reset_requested', event_payload(user))
            end

            # Always 202, whether or not anything matched — this endpoint must
            # not become a way to discover which addresses exist.
            render json: { message: Spree.t(:password_reset_requested, scope: :api) }, status: :accepted
          end

          # PATCH /api/v3/seller/auth/password_resets/:id
          def update
            user = Spree.admin_user_class.find_by_password_reset_token(params[:id])

            # Membership is re-checked here rather than trusted from the token:
            # it can be revoked between the email being sent and the link being
            # opened, and signing in is what the success path does.
            return render_token_invalid unless user&.seller_member?

            unless user.update(password: params[:password], password_confirmation: params[:password_confirmation])
              return render_errors(user.errors)
            end

            user.publish_event('seller_user.password_reset')

            # A reset must kill every existing session — a stolen refresh token
            # must not survive the victim resetting their password. Revoked
            # across every audience, since the password is what they all rest
            # on. Then mint the fresh one for this browser.
            Spree::RefreshToken.revoke_all_for(user)
            set_refresh_cookie(
              Spree::RefreshToken.create_for(
                user,
                audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER,
                request_env: request_env_for_token
              )
            )

            render json: auth_response(user)
          end

          private

          # A token that no longer belongs to a seller is reported exactly as an
          # expired or forged one: the caller is unauthenticated either way, and
          # distinguishing them would leak that the address is a real account.
          def render_token_invalid
            render_error(
              code: ErrorHandler::ERROR_CODES[:password_reset_token_invalid],
              message: Spree.t(:password_reset_token_invalid, scope: :api),
              status: :unprocessable_content
            )
          end

          # The store is carried on the event so the mailer can resolve the
          # right panel origin and locale without a request to read them from.
          def event_payload(user)
            store = seller_store(user)
            payload = {
              reset_token: user.generate_token_for(:password_reset),
              email: user.email,
              store_id: store&.prefixed_id
            }
            redirect_url = validated_redirect_url(store)
            payload[:redirect_url] = redirect_url if redirect_url.present?
            payload
          end

          # Which store's panel to send them to.
          #
          # Derived from the seller, never from `current_store`: this endpoint
          # is unauthenticated, so the request carries no seller header and
          # `current_store` is simply the default store — which on a
          # multi-store install is the wrong marketplace entirely. The seller
          # branch's rule is that the store follows the seller.
          def seller_store(user)
            user.sellers.first&.store
          end

          # Honoured only when it points somewhere the seller's own store has
          # vouched for. An unvalidated value would let anyone with the reset
          # form turn this endpoint into a token-exfiltration channel, and
          # judging it against the default store's allowlist would let one
          # marketplace's origins approve a link mailed to another's seller.
          # Dropping it leaves the mailer to resolve the panel origin itself.
          def validated_redirect_url(store)
            url = params[:redirect_url].presence
            return unless url && store
            return unless store.allowed_origins.exists? && store.allowed_origin?(url)

            url
          end

          # Same shape as the login response, so the panel can sign them
          # straight in rather than bouncing them to a login form.
          def auth_response(user)
            {
              token: generate_jwt(user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER),
              user: Spree.api.seller_team_member_serializer.new(
                user, params: { store: seller_store(user) }
              ).to_h,
              sellers: serialized_sellers(user)
            }
          end

          # The panel needs these to choose an X-Spree-Seller-Id before it can
          # make any other request.
          def serialized_sellers(user)
            user.sellers.map { |seller| { id: seller.prefixed_id, name: seller.name, status: seller.status } }
          end

          def request_env_for_token
            { ip_address: request.remote_ip, user_agent: request.user_agent&.truncate(255) }
          end

          def jwt_expiration
            Spree::Api::Config[:admin_jwt_expiration]
          end
        end
      end
    end
  end
end
