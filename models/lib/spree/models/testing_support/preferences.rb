module Spree
  module Models
    module TestingSupport
      module Preferences
        def reset_spree_preferences(&config_block)
          Spree::Preferences::Store.instance.persistence = false
          Spree::Preferences::Store.instance.clear_cache

          configure_spree_preferences &config_block if block_given?
        end

        # The preference cache is cleared before each test, so the
        # default values will be used. You can define preferences
        # for your spec with:
        #
        # configure_spree_preferences do |config|
        #   config.site_name = "my fancy pants store"
        # end
        #
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
end
