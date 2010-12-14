module Spree::PreferenceAccess

  def self.included(base)
    class << base
      def get(key = nil)
        key = key.to_s if key.is_a?(Symbol)
        return nil unless config = self.instance
        # preferences will be cached under the name of the class including this module (ex. Spree::Config)
        prefs = Rails.cache.fetch("configuration_#{config.id}".to_sym) { config.preferences }
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
        Rails.cache.delete("configuration_#{config.id}".to_sym)
      end

      alias_method :[], :get
    end
  end
end
