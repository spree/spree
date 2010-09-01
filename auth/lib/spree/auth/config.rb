module Spree
  module Auth
    # Singleton class to access the shipping configuration object (ActiveShippingConfiguration.first by default) and it's preferences.
    #
    # Usage:
    #   Spree::Auth::Config[:foo]                  # Returns the foo preference
    #   Spree::Auth::Config[]                      # Returns a Hash with all the tax preferences
    #   Spree::Auth::Config.instance               # Returns the configuration object (AuthConfiguration.first)
    #   Spree::Auth::Config.set(preferences_hash)  # Set the spree auth preferences as especified in +preference_hash+
    class Config
      include Singleton
      include Spree::PreferenceAccess

      class << self
        def instance
          return nil unless ActiveRecord::Base.connection.tables.include?('configurations')
          SpreeAuthConfiguration.find_or_create_by_name("Default spree_auth configuration")
        end
      end
    end
  end
end