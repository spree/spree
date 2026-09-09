module Spree
  module Api
    module V3
      module JwtAuthentication
        extend ActiveSupport::Concern

        include Spree::Api::V3::ErrorHandler

        USER_TYPE_CUSTOMER = 'customer'.freeze
        USER_TYPE_ADMIN = 'admin'.freeze

        JWT_AUDIENCE_STORE = 'store_api'.freeze
        JWT_AUDIENCE_ADMIN = 'admin_api'.freeze
        # Marketplace sellers share the admin user class, so the audience — not
        # the principal — is what keeps a seller's token off the admin API and
        # an admin's off the seller panel. Enforced at decode, before any store
        # or seller is resolved.
        JWT_AUDIENCE_SELLER = 'seller_api'.freeze
        JWT_ISSUER = 'spree'.freeze

        included do
          attr_reader :current_user
        end

        # Optional authentication - doesn't fail if no token
        def authenticate_user
          token = extract_token
          return unless token.present?

          payload = decode_jwt(token)
          @current_user = find_user_from_payload(payload)
        rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::InvalidIssuerError,
               JWT::InvalidAudError, ActiveRecord::RecordNotFound => e
          Rails.logger.debug { "JWT authentication failed: #{e.message}" }
          @current_user = nil
        end

        # Required authentication - fails if no valid token
        # Returns true if authenticated, false otherwise (also renders error and halts)
        def require_authentication!
          authenticate_user

          return true if current_user

          render_error(code: ErrorHandler::ERROR_CODES[:authentication_required], message: 'Authentication required', status: :unauthorized)
          false
        end

        protected

        # Generate a JWT token for a user
        # @param user [Object] The user to generate a token for
        # @param expiration [Integer] Time in seconds until expiration (default from config, 1 hour)
        # @param audience [String] The audience claim (default: store_api)
        # @return [String] The JWT token
        def generate_jwt(user, expiration: jwt_expiration, audience: JWT_AUDIENCE_STORE)
          payload = {
            user_id: user.id,
            user_type: determine_user_type(user),
            jti: SecureRandom.uuid,
            iss: JWT_ISSUER,
            aud: audience,
            exp: Time.current.to_i + expiration
          }
          JWT.encode(payload, jwt_secret, 'HS256')
        end

        private

        def extract_token
          # Check Authorization header first
          header = request.headers['Authorization']
          return header.split(' ').last if header.present? && header.start_with?('Bearer ')

          # Restricted fallback: only the storefront tokenized download
          # endpoint, which carries its link token in the query string. The
          # customer library and admin grant endpoints share the controller
          # name but authenticate by header, so matching on the name alone
          # would let their bearer JWTs travel in the URL (logs, history).
          params[:token] if controller_path == 'spree/api/v3/store/digital_links'
        end

        def decode_jwt(token)
          JWT.decode(token, jwt_secret, true,
            algorithm: 'HS256',
            iss: JWT_ISSUER,
            aud: expected_audience,
            verify_iss: true,
            verify_aud: true
          ).first
        end

        def jwt_secret
          Spree::Api::Config[:jwt_secret_key].presence ||
            Rails.application.credentials.jwt_secret_key ||
            ENV['JWT_SECRET_KEY'] ||
            Rails.application.secret_key_base
        end

        def jwt_expiration
          Spree::Api::Config[:jwt_expiration]
        end

        def expected_audience
          JWT_AUDIENCE_STORE
        end

        def find_user_from_payload(payload)
          user_id = payload['user_id']
          user_type = payload['user_type'] || USER_TYPE_CUSTOMER

          case user_type
          when USER_TYPE_ADMIN
            Spree.admin_user_class.find(user_id)
          else
            customer_from(user_id)
          end
        end

        # An erased account stops answering to its old tokens. Clearing the
        # password blocks a fresh sign-in, but a JWT issued before the erasure
        # would otherwise keep working until it expired — long enough to write
        # a name and phone back onto the record, after which a second erasure
        # is refused as already done.
        def customer_from(user_id)
          customer = Spree.customer_class.find(user_id)

          customer.respond_to?(:anonymized?) && customer.anonymized? ? nil : customer
        end

        def determine_user_type(user)
          if user.is_a?(Spree.admin_user_class)
            USER_TYPE_ADMIN
          else
            USER_TYPE_CUSTOMER
          end
        end
      end
    end
  end
end
