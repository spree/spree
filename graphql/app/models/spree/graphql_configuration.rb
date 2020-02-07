module Spree
  class GraphqlConfiguration < Preferences::Configuration
    preference :graphql_expiration, :integer, default: 86400 # 24hours
    preference :graphql_secret_key, :string, default: -> { self.graphql_secret_key }

    def self.graphql_secret_key
      if defined?(Rails)
        Rails.application.secrets.secret_key_base.to_s
      else
        raise 'Set secret key for GraphQL jwt token'
      end
    end
  end
end
