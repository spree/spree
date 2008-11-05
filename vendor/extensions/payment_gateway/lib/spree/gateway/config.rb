module Spree
  module Gateway
    # Singleton class to access the gateway configuration object (GatewayConfiguration.first by default) and it's preferences.
    #
    # Usage:
    #   Spree::Gateway::Config[:foo]                  # Returns the foo preference
    #   Spree::Gateway::Config[]                      # Returns a Hash with all the gateway preferences
    #   Spree::Gateway::Config.instance               # Returns the configuration object (GatewayConfiguration.first)
    #   Spree::Gateway::Config.set(preferences_hash)  # Set the gateway preferences as especified in +preference_hash+
    class Config
      include Singleton
      include PreferenceAccess
    
      class << self
        def instance
          return nil unless ActiveRecord::Base.connection.tables.include?('configurations')
          GatewayConfig.find_or_create_by_name("Default gateway configuration")
        end
      end
    end
  end
end