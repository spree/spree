module Spree
  module TestingSupport
    module Preferences
      # Resets all preferences to default values, you can
      # pass a block to override the defaults with a block
      #
      # reset_spree_preferences do |config|
      #   config.site_name = "my fancy pants store"
      # end
      #
      def reset_spree_preferences(&config_block)
        Spree::Preferences::Store.instance.persistence = false
        Spree::Preferences::Store.instance.clear_cache

        config = Rails.application.config.spree.preferences
        configure_spree_preferences &config_block if block_given?
      end

      def configure_spree_preferences
        config = Rails.application.config.spree.preferences
        yield(config) if block_given?
      end

      def assert_preference_unset(preference)
        find("#preferences_#{preference}")['checked'].should be_false
        Spree::Config[preference].should be_false
      end
    end
  end
end

