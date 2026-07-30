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
          return failure('Account temporarily locked. Try again later.') if user.respond_to?(:locked?) && user.locked?

          if validate_password(user, password)
            user.reset_failed_attempts! if user.respond_to?(:reset_failed_attempts!) && user.failed_attempts.to_i.positive?
            success(user)
          else
            user.record_failed_attempt! if user.respond_to?(:record_failed_attempt!)
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
          # Duck-typed so any customer_class works: prefer valid_password?
          # (defined by the gem models and legacy/custom models alike), then
          # fall back to has_secure_password's authenticate.
          if user.respond_to?(:valid_password?)
            user.valid_password?(password)
          elsif user.respond_to?(:authenticate)
            user.authenticate(password).present?
          else
            Rails.logger.warn "User class #{user.class} does not implement password authentication"
            false
          end
        end
      end
    end
  end
end
