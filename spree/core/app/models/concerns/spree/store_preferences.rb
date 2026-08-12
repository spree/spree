module Spree
  # Reads a store-scoped commerce setting from a record that is not itself a
  # store.
  #
  # Spree 6 moved settings that shape how a shop sells from +Spree::Config+
  # onto +Spree::Store+, and core reads the store with no fallback to the old
  # global — two sources of truth are what let them drift apart. Including
  # models say how they reach a store by defining +preference_store+; when they
  # can't reach one (a product with no store, a class-level scope, a console
  # session), the read falls back to the preference's own declared default
  # rather than raising.
  module StorePreferences
    extend ActiveSupport::Concern

    # @param name [Symbol] preference declared on Spree::Store
    # @return [Object] the store's value, or the preference default
    def store_preference(name)
      Spree::StorePreferences.read(preference_store, name)
    end

    # The store whose settings apply to this record. Override in models whose
    # route to a store isn't a +store+ association.
    # @return [Spree::Store, nil]
    def preference_store
      respond_to?(:store) ? store : nil
    end

    class << self
      # @param store [Spree::Store, nil]
      # @param name [Symbol] preference declared on Spree::Store
      # @return [Object] the store's value, or the preference default
      def read(store, name)
        return store.get_preference(name) if store

        # `preference_default` is defined per instance, not on the class, and
        # an unsaved store is enough to read a declared default.
        Spree::Store.new.preference_default(name)
      end

      # Reads a setting outside any record — class-level scopes and services
      # that have no owning row to ask. Resolves the ambient store.
      # @param name [Symbol] preference declared on Spree::Store
      # @return [Object] the current store's value, or the preference default
      def current(name)
        read(Spree::Current.store, name)
      end
    end
  end
end
