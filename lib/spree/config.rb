module Spree
  # Singleton class to access the configuration object (AppConfiguration.first by default) and it's preferences.
  #
  # Usage:
  #   Spree::Config[:mail_host]       # Returns the +mail_host+ preference
  #   Spree::Config[]                 # Returns a Hash with all the application preferences
  #   Spree::Config.intance           # Returns the configuration object (AppConfiguration.first)
  #   Spree::Config.set(preferences_hash)  # Set the application preferences as especified in +preferences+
  class Config

    include Singleton
    
    class << self

      def instance
        return nil unless ActiveRecord::Base.connection.tables.include?('app_configurations')
        AppConfiguration.find_or_create_by_name("Default configuration")
      end

      def get(key = nil)
        key = key.to_s if key.is_a?(Symbol)
        return nil unless config = self.instance
        prefs = Rails.cache.fetch("spree_current_preferences") { config.preferences }
        return prefs if key.nil?
        prefs[key]
      end

      # Set the preferences as specified in a hash (like params[:preferences] from a post request)
      def set(preferences={})
        config = self.instance
        preferences.each do |key, value|
          config.set_preference(key, value)
        end
        config.save
        Rails.cache.delete("spree_current_preferences") { config.preferences }
      end
      
      alias_method :[], :get
    end
  end
end
