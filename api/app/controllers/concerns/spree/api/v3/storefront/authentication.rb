module Spree
  module Api
    module V3
      module Storefront
        # This concern provides helper methods for generating JWT tokens
        # For authentication verification, see Spree::Api::V3::Authentication
        module Authentication
          extend ActiveSupport::Concern

          protected

          # Generate a JWT token for a user
          # @param user [Spree.user_class] The user to generate a token for
          # @param expiration [Integer] Time in seconds until expiration (default 24 hours)
          # @return [String] The JWT token
          def generate_jwt(user, expiration: 24.hours.to_i)
            payload = {
              user_id: user.id,
              exp: Time.current.to_i + expiration
            }
            JWT.encode(payload, jwt_secret, 'HS256')
          end

          private

          def jwt_secret
            Rails.application.credentials.jwt_secret_key || ENV['JWT_SECRET_KEY'] || Rails.application.secret_key_base
          end
        end
      end
    end
  end
end
