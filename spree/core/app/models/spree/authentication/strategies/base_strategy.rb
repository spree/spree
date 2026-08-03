module Spree
  module Authentication
    module Strategies
      class BaseStrategy
        attr_reader :params, :request_env, :user_class

        class << self
          # How a client initiates login with this strategy.
          #
          # +:password+ — the client posts credentials to the auth endpoint.
          # +:redirect+ — the client sends the browser to the identity provider,
          # which returns through the OAuth callback.
          #
          # Defaults to +:password+ so strategies written before provider
          # discovery existed keep describing themselves correctly.
          # @return [Symbol]
          def kind
            :password
          end

          # Human-readable provider name for the login button. Only meaningful for
          # +:redirect+ strategies; defaults to nil so password strategies render
          # their standard form instead of a button.
          # @return [String, nil]
          def label
            nil
          end
        end

        def initialize(params:, request_env:, user_class: nil)
          @params = params
          @request_env = request_env
          @user_class = user_class || Spree.customer_class
        end

        # Where to send the browser to begin authentication. Redirect strategies
        # must implement this; password strategies never call it.
        #
        # @param state [String] opaque CSRF token echoed back to the callback
        # @return [String] the identity provider's authorization URL
        def authorization_url(state:)
          raise NotImplementedError, 'Redirect strategies must implement #authorization_url'
        end

        # Completes a redirect login from the identity provider's callback params.
        # Redirect strategies must implement this; password strategies use
        # +#authenticate+ instead.
        #
        # @return [Spree::ServiceModule::Result] the resolved user on success
        def callback
          raise NotImplementedError, 'Redirect strategies must implement #callback'
        end

        # Returns Result object with user on success
        # @return [Spree::ServiceModule::Result]
        def authenticate
          raise NotImplementedError, 'Subclass must implement #authenticate'
        end

        # Returns provider identifier (e.g., 'google', 'email')
        # @return [String]
        def provider
          raise NotImplementedError, 'Subclass must implement #provider'
        end

        protected

        # Success result with user
        def success(user)
          Spree::ServiceModule::Result.new(success: true, value: user)
        end

        # Failure result with error message
        def failure(message)
          Spree::ServiceModule::Result.new(success: false, error: message)
        end

        # Find user by email
        def find_user_by_email(email)
          user_class.find_by(email: email)
        end

        # Find or create user identity
        def find_or_create_user_from_oauth(provider:, uid:, info:, tokens: {})
          Spree::UserIdentity.find_or_create_from_oauth(
            provider: provider,
            uid: uid,
            info: info,
            tokens: tokens,
            user_class: user_class
          )
        end
      end
    end
  end
end
