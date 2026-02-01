module Spree
  module Authentication
    module Strategies
      class GoogleStrategy < BaseStrategy
        def authenticate
          id_token = params[:id_token]
          return failure('Google ID token is required') if id_token.blank?

          # Verify Google ID token
          payload = verify_google_token(id_token)
          return failure('Invalid Google token') unless payload

          # Extract user info from Google payload
          info = {
            email: payload['email'],
            first_name: payload['given_name'],
            last_name: payload['family_name']
          }

          # Find or create user with identity
          user = find_or_create_user_from_oauth(
            provider: provider,
            uid: payload['sub'],
            info: info,
            tokens: {
              access_token: id_token,
              expires_at: Time.at(payload['exp'])
            }
          )

          success(user)
        rescue => e
          Rails.logger.error "GoogleStrategy authentication failed: #{e.message}"
          failure('Google authentication failed')
        end

        def provider
          'google'
        end

        private

        def verify_google_token(token)
          # This requires google-id-token gem or similar
          # For production, use: Google::Auth::IDTokens.verify_oidc(token, aud: google_client_id)
          # For now, return a basic implementation that developers can override

          if defined?(Google::Auth::IDTokens)
            Google::Auth::IDTokens.verify_oidc(token, aud: google_client_id)
          else
            # Fallback for development - decode without verification
            # WARNING: This should never be used in production!
            Rails.logger.warn 'Google token verification skipped - install google-id-token gem for production'
            JWT.decode(token, nil, false).first
          end
        rescue => e
          Rails.logger.error "Google token verification failed: #{e.message}"
          nil
        end

        def google_client_id
          ENV['GOOGLE_CLIENT_ID'] || Rails.application.credentials.dig(:google, :client_id)
        end
      end
    end
  end
end
