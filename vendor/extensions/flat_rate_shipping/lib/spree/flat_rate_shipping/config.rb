module Spree
  module FlatRateShipping
    # Singleton class to access the tax configuration object (TaxConfiguration.first by default) and it's preferences.
    #
    # Usage:
    #   Spree::FlatRateShipping::Config[:foo]                  # Returns the foo preference
    #   Spree::FlatRateShipping::Config[]                      # Returns a Hash with all the tax preferences
    #   Spree::FlatRateShipping::Config.instance               # Returns the configuration object (TaxConfiguration.first)
    #   Spree::FlatRateShipping::Config.set(preferences_hash)  # Set the tax preferences as especified in +preference_hash+
    class Config
      include Singleton
      include PreferenceAccess
    
      class << self
        def instance
          return nil unless ActiveRecord::Base.connection.tables.include?('configurations')
          FlatRateShippingConfiguration.find_or_create_by_name("Default tax configuration")
        end
      end
    end
  end
end