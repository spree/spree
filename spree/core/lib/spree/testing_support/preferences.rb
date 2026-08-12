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

      # Stubs store-scoped commerce settings for the duration of one example.
      #
      #   stub_store_preferences(track_inventory_levels: false)
      #   stub_store_preferences(other_store, auto_capture: false)
      #
      # Stubs rather than writes: the suite-wide +@default_store+ is shared by
      # every example, so persisting a setting here would leak into whatever
      # runs next.
      #
      # Stubbing is keyed on the store's id rather than a single object, because
      # code under test reaches its store through an association or a reload and
      # so holds a different instance of the same row. Stores with another id —
      # and preferences not listed here — keep their real values.
      #
      # Reads funnel through +get_preference+ and the generated
      # +preferred_<name>+ accessor, so both are stubbed.
      def stub_store_preferences(store = nil, **preferences)
        store ||= @default_store
        store_id = store.id

        preferences.each do |name, value|
          allow_any_instance_of(Spree::Store).to receive(:get_preference).
            with(name).and_wrap_original do |original, *args|
              original.receiver.id == store_id ? value : original.call(*args)
            end

          allow_any_instance_of(Spree::Store).to receive(:"preferred_#{name}").
            and_wrap_original do |original, *args|
              original.receiver.id == store_id ? value : original.call(*args)
            end
        end

        # Preferences this call doesn't name must still answer for themselves.
        allow_any_instance_of(Spree::Store).to receive(:get_preference).
          with(satisfy { |name| !preferences.key?(name) }).and_call_original

        store
      end
    end
  end
end
