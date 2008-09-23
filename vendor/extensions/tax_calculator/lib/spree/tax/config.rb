module Spree
  module Tax
    # Singleton class to access the tax configuration object (TaxConfiguration.first by default) and it's preferences.
    #
    # Usage:
    #   Spree::Tax::Config[:foo]                  # Returns the foo preference
    #   Spree::Tax::Config[]                      # Returns a Hash with all the tax preferences
    #   Spree::Tax::Config.instance               # Returns the configuration object (TaxConfiguration.first)
    #   Spree::Tax::Config.set(preferences_hash)  # Set the tax preferences as especified in +preference_hash+
    class Config
      include Singleton
      include PreferenceAccess
    
      class << self
        def instance
          return nil unless ActiveRecord::Base.connection.tables.include?('configurations')
          TaxConfiguration.find_or_create_by_name("Default tax configuration")
        end
      end
    end
  end
end