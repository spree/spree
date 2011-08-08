module Spree
  module Paperclip
    # Singleton class to access the Paperclip configuration object (PaperclipConfiguration.first by default) and it's preferecnes.
    #
    # Usage:
    #   Spree::Paperclip::Config[:foo]                  # Returns the foo preference
    #   Spree::Paperclip::Config[]                      # Returns a Hash with all the tax preferences
    #   Spree::Paperclip::Config.instance               # Returns the configuration object (Paperclip.first)
    #   Spree::Paperclip::Config.set(preferences_hash)  # Set the tax preferences as especified in 
    class Config
      include Singleton
      include PreferenceAccess
      class << self
        def instance
          return nil unless ActiveRecord::Base.connection.tables.include? 'configurations'
          PaperclipConfiguration.find_or_create_by_name('Default Paperclip configuration.')
        end

        # Return the configuration as a hash, ready to be passed into has_attached_file
        def to_h
          {}.tap do |hash|
            instance.preferences.each do |index,value|
              hash[index.to_sym] = value
            end
          end
        end

        # Merge in the arguments to the defaults.
        def merge opts={}
          to_h.merge(opts)
        end

      end
    end
  end
end
