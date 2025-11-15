module Spree
  module Api
    module V3
      module Authentication
        extend ActiveSupport::Concern

        include Spree::Api::V3::ErrorHandler

        included do
          attr_reader :current_user
        end

        # Optional authentication - doesn't fail if no token
        def authenticate_user
          token = extract_token
          return unless token.present?

          payload = decode_jwt(token)
          @current_user = Spree.user_class.find(payload['user_id'])
        rescue JWT::DecodeError, JWT::ExpiredSignature, ActiveRecord::RecordNotFound => e
          Rails.logger.debug { "JWT authentication failed: #{e.message}" }
          @current_user = nil
        end

        # Required authentication - fails if no valid token
        def require_authentication!
          authenticate_user

          unless current_user
            render_error(code: ErrorHandler::ERROR_CODES[:authentication_required], message: 'Authentication required', status: :unauthorized)
            return false
          end
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
      end
    end
  end
end
