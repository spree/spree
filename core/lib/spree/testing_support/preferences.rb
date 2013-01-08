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
      def reset_spree_preferences
        Spree::Preferences::Store.instance.persistence = false
        config = Rails.application.config.spree.preferences
        config.reset
        yield(config) if block_given?
      end

      def assert_preference_unset(preference)
        find("#preferences_#{preference}")['checked'].should be_false
        Spree::Config[preference].should be_false
      end
    end
  end
end
