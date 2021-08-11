module Spree
  module Api
    module Oauth
      class GenerateToken
        prepend ::Spree::ServiceModule::Base

        def call(app:, scopes: nil, user: nil)
          scopes ||= app.scopes

          token = token_model_class.find_or_create_for(
            application: app,
            resource_owner: user,
            scopes: scopes
          )

          success(token)
        end

        protected

        def token_model_class
          ::Doorkeeper::AccessToken
        end
      end
    end
  end
end
