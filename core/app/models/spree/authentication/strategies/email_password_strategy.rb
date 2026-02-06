module Spree
  module Authentication
    module Strategies
      class EmailPasswordStrategy < BaseStrategy
        def authenticate
          email = params[:email]
          password = params[:password]

          return failure('Email is required') if email.blank?
          return failure('Password is required') if password.blank?

          user = find_user_by_email(email)
          return failure('Invalid email or password') unless user

          if validate_password(user, password)
            success(user)
          else
            failure('Invalid email or password')
          end
        rescue => e
          Rails.logger.error "EmailPasswordStrategy authentication failed: #{e.message}"
          failure('Authentication failed')
        end

        def provider
          'email'
        end

        private

        def validate_password(user, password)
          # Try Devise's valid_password? method first (most common)
          if user.respond_to?(:valid_password?)
            user.valid_password?(password)
          # Fallback to authenticate method (for has_secure_password)
          elsif user.respond_to?(:authenticate)
            user.authenticate(password).present?
          else
            # No password authentication available
            Rails.logger.warn "User class #{user.class} does not implement password authentication"
            false
          end
        end
      end
    end
  end
end
