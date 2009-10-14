module Spree
  # Singleton class to access the configuration object (AppConfiguration.first by default) and it's preferences.
  #
  # Usage:
  #   Spree::Config[:foo]                  # Returns the +foo+ preference
  #   Spree::Config[]                      # Returns a Hash with all the application preferences
  #   Spree::Config.instance               # Returns the configuration object (AppConfiguration.first)
  #   Spree::Config.set(preferences_hash)  # Set the application preferences as especified in +preference_hash+
  class Config
    include Singleton
    include PreferenceAccess
    
    class << self
      def instance
        return nil unless ActiveRecord::Base.connection.tables.include?('configurations')
        AppConfiguration.find_or_create_by_name("Default configuration")
      end
      
      def searcher
        @searcher ||= Spree::Search::Base.new
      end
      
      def searcher=(searcher_obj)
        @searcher = searcher_obj  
      end
    end
  end
end
