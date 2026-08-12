module Spree
  module TestingSupport
    module Preferences
      # Resets all preferences to default values, you can
      # pass a block to override the defaults with a block
      #
      # reset_spree_preferences do |config|
      #   config.track_inventory_levels = false
      # end
      #
      def reset_spree_preferences(&config_block)
        config = Rails.application.config.spree.preferences.reset
        configure_spree_preferences &config_block if block_given?
      end

      def configure_spree_preferences
        config = Rails.application.config.spree.preferences
        yield(config) if block_given?
      end

      def assert_preference_unset(preference)
        find("#preferences_#{preference}")['checked'].should be false
        Spree::Config[preference].should be false
      end

      # Sets store-scoped commerce settings for the duration of one example.
      #
      #   set_store_preferences(track_inventory_levels: false)
      #   set_store_preferences(store, auto_capture: false)
      #
      # Defaults to the suite-wide +@default_store+, which every example shares.
      # Records what it overwrote so the RSpec config's `after` hook can restore
      # it — without that, a store setting leaks into whatever runs next.
      def set_store_preferences(store = nil, **preferences)
        store ||= @default_store
        @overridden_store_preferences ||= {}
        recorded = (@overridden_store_preferences[store] ||= {})

        preferences.each do |name, value|
          recorded[name] = store.get_preference(name) unless recorded.key?(name)
          store.set_preference(name, value)
        end
        store.save!
      end

      # Puts back everything {#set_store_preferences} overwrote in this example.
      def restore_store_preferences
        return if @overridden_store_preferences.blank?

        @overridden_store_preferences.each do |store, preferences|
          preferences.each { |name, value| store.set_preference(name, value) }
          store.save!
        end
        @overridden_store_preferences = nil
      end
    end
  end
end
