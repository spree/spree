module Spree
  module Api
    module V3
      module JwtAuthentication
        extend ActiveSupport::Concern

        include Spree::Api::V3::ErrorHandler

        USER_TYPE_CUSTOMER = 'customer'.freeze
        USER_TYPE_ADMIN = 'admin'.freeze

        included do
          attr_reader :current_user
        end

        # Optional authentication - doesn't fail if no token
        def authenticate_user
          token = extract_token
          return unless token.present?

          payload = decode_jwt(token)
          @current_user = find_user_from_payload(payload)
        rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound => e
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
        # @param expiration [Integer] Time in seconds until expiration (default 24 hours)
        # @return [String] The JWT token
        def generate_jwt(user, expiration: 24.hours.to_i)
          payload = {
            user_id: user.id,
            user_type: determine_user_type(user),
            exp: Time.current.to_i + expiration
          }
          JWT.encode(payload, jwt_secret, 'HS256')
        end

        private

        def extract_token
          # Check Authorization header first
          header = request.headers['Authorization']
          return header.split(' ').last if header.present? && header.start_with?('Bearer ')

          # Fallback to query param for special cases (e.g., digital downloads)
          params[:token]
        end

        def decode_jwt(token)
          JWT.decode(token, jwt_secret, true, algorithm: 'HS256').first
        end

        def jwt_secret
          Rails.application.credentials.jwt_secret_key || ENV['JWT_SECRET_KEY'] || Rails.application.secret_key_base
        end

        def find_user_from_payload(payload)
          user_id = payload['user_id']
          user_type = payload['user_type'] || USER_TYPE_CUSTOMER

          case user_type
          when USER_TYPE_ADMIN
            Spree.admin_user_class.find(user_id)
          else
            Spree.user_class.find(user_id)
          end
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
