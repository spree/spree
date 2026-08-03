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
    #
    # An entry may be either a strategy **class** or a configured **factory** —
    # any object responding to +#build(params:, request_env:, user_class:)+.
    # Factories let one class serve several registrations with different settings
    # (an OIDC strategy pointed at two different issuers, say), which a bare class
    # cannot express.
    #
    # @example Registering a configured factory
    #   Spree.admin_authentication_strategies.add(
    #     :entra,
    #     Spree::Authentication::Strategies::OidcStrategy.configure(
    #       issuer: 'https://login.microsoftonline.com/<tenant>/v2.0',
    #       client_id: ENV['ENTRA_CLIENT_ID'],
    #       client_secret: ENV['ENTRA_CLIENT_SECRET'],
    #       label: 'Microsoft Entra ID'
    #     )
    #   )
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

      # Instantiates the strategy registered under +key+, accepting either a bare
      # class or a configured factory.
      #
      # @param key [Symbol, String] provider identifier
      # @return [Object, nil] a strategy instance, or nil if no such key
      def build(key, params:, request_env:, user_class: nil)
        entry = self[key]
        return nil if entry.nil?

        if entry.respond_to?(:build)
          entry.build(params: params, request_env: request_env, user_class: user_class)
        else
          entry.new(params: params, request_env: request_env, user_class: user_class)
        end
      end

      # Self-description of every registered strategy, for the provider-discovery
      # endpoint that drives the dashboard login page.
      #
      # Exposes only what a login screen needs — never client secrets, never
      # strategy class names.
      #
      # @return [Array<Hash>] one entry per registered provider
      # @yieldparam key [Symbol] provider key, for minting a per-provider CSRF state
      # @return [Array<Hash>] one entry per registered provider
      def describe
        @strategies.map do |key, entry|
          kind = kind_of(entry)
          descriptor = { key: key.to_s, kind: kind.to_s }
          descriptor[:label] = label_of(entry)

          if kind == :redirect
            state = block_given? ? yield(key) : nil
            descriptor[:authorization_url] = authorization_url_for(entry, state: state)
          end

          descriptor.compact
        end
      end

      private

      # Registry entries predate the kind/label contract — a strategy registered
      # before it existed (or one that does not inherit BaseStrategy) must not
      # raise here, because describe backs the unauthenticated login page and one
      # bad entry would take down sign-in for everyone.
      def kind_of(entry)
        entry.respond_to?(:kind) ? entry.kind.to_sym : :password
      end

      def label_of(entry)
        return nil unless entry.respond_to?(:label)

        entry.label.presence
      end

      # A misconfigured provider (bad issuer, unreachable discovery document)
      # must not take down the whole login page — it drops out of the list
      # instead, leaving the remaining providers usable.
      def authorization_url_for(entry, state:)
        entry.authorization_url(state: state)
      rescue StandardError => e
        Rails.logger.error("[Spree] Could not build authorization URL for #{label_of(entry) || entry}: #{e.message}")
        nil
      end
    end
  end
end
