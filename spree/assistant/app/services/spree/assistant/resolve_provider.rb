module Spree
  module Assistant
    # Works out which AI vendor this store talks to, and with what credentials.
    #
    # The store preference chooses the vendor; the vendor's own integration card
    # supplies the key. Returns nil when nothing is connected, which is what
    # makes the assistant panel hide itself rather than fail mid-question.
    class ResolveProvider
      # @param store [Spree::Store]
      def initialize(store:)
        @store = store
      end

      # @return [Hash, nil] provider key, api key and model
      def call
        provider_class&.credentials_for(store)
      end

      # @return [Class<Spree::AssistantProvider::Base>, nil]
      def provider_class
        key = store.preferred_assistant_provider.presence || Spree::Assistant::DEFAULT_PROVIDER_KEY

        Spree.assistant_providers.find { |provider| provider.provider_key.to_s == key.to_s }
      end

      # @return [Boolean] whether a merchant could chat right now
      def available?
        call.present?
      end

      private

      attr_reader :store
    end
  end
end
