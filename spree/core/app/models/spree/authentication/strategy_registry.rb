require 'forwardable'

module Spree
  module Authentication
    # Keyed registry of authentication strategy classes for the Store and Admin APIs.
    #
    # Strategies are dispatched by the `provider` value the client sends to the auth
    # endpoint, so the registry is a key → class map. The `:email` key is reserved for
    # the built-in {Spree::Authentication::Strategies::EmailPasswordStrategy}; integrators
    # can override it by adding a different class under the same key.
    #
    # @example Registering a custom provider
    #   Spree.store_authentication_strategies.add(:auth0, MyApp::Auth::Auth0Strategy)
    #
    # @example Removing a provider
    #   Spree.store_authentication_strategies.remove(:email)
    #
    # @example Reading a strategy class
    #   Spree.store_authentication_strategies[:email]
    class StrategyRegistry
      extend Forwardable
      include Enumerable

      def_delegators :@strategies, :keys, :values, :each

      def initialize(strategies = {})
        @strategies = {}
        strategies.each { |key, klass| add(key, klass) }
      end

      # Register a strategy class under the given provider key. Overwrites any
      # existing entry for that key.
      #
      # @param key [Symbol, String] provider identifier sent by the client
      # @param strategy_class [Class] strategy class (typically a subclass of
      #   {Spree::Authentication::Strategies::BaseStrategy})
      # @return [Class] the registered class
      def add(key, strategy_class)
        @strategies[key.to_sym] = strategy_class
      end

      # Unregister a strategy. Idempotent — returns `nil` if the key is not present.
      #
      # @param key [Symbol, String]
      # @return [Class, nil] the removed class, or nil if no such key
      def remove(key)
        @strategies.delete(key.to_sym)
      end

      # Look up a registered strategy class.
      #
      # @param key [Symbol, String] provider identifier
      # @return [Class, nil] the registered strategy class, or nil if no such key
      def [](key)
        @strategies[key.to_sym]
      end

      # Whether a strategy is registered under the given provider key.
      #
      # @param key [Symbol, String]
      # @return [Boolean]
      def key?(key)
        @strategies.key?(key.to_sym)
      end

      # @return [Hash{Symbol => Class}] a shallow copy of the underlying map
      def to_h
        @strategies.dup
      end
    end
  end
end
