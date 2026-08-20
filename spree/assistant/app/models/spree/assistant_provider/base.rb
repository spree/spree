module Spree
  module AssistantProvider
    # An AI vendor the assistant can run on.
    #
    # Follows the delivery-rate / tax provider pattern: the class names the
    # vendor and points at the {Spree::Integration} subclass holding its
    # credentials, so a store picks a provider the same way it picks a tax
    # engine, and extensions register their own without patching core.
    #
    #   Spree.assistant_providers << MyApp::AssistantProvider::Bedrock
    class Base
      class << self
        # @return [String] name shown in the store settings picker
        def display_name
          name.demodulize.titleize
        end

        # Key RubyLLM knows this vendor by.
        #
        # @return [Symbol]
        def provider_key
          raise NotImplementedError, 'Assistant providers must declare a provider_key'
        end

        # @return [String] class name of the Spree::Integration holding credentials
        def integration_class
          nil
        end

        # @return [String] model used when the merchant has not chosen one
        def default_model
          raise NotImplementedError, 'Assistant providers must declare a default_model'
        end

        # @param store [Spree::Store]
        # @return [Boolean] whether this store has connected this vendor
        def available_for_store?(store)
          return false if integration_class.blank?

          store.present? && store.integrations.active.exists?(type: integration_class)
        end

        # @param store [Spree::Store]
        # @return [Spree::Integration, nil]
        def integration_for(store)
          return if integration_class.blank?

          store&.integrations&.active&.find_by(type: integration_class)
        end

        # Shape the dashboard's provider picker reads.
        #
        # @param store [Spree::Store]
        # @return [Hash]
        def to_api_hash(store)
          {
            id: name,
            key: provider_key.to_s,
            name: display_name,
            default_model: default_model,
            integration_type: integration_class,
            available: available_for_store?(store)
          }
        end

        # Credentials for a chat, resolved from this store's integration.
        # Returns nil when the vendor is not connected — the caller answers
        # "assistant unavailable" rather than calling an API with no key.
        #
        # @param store [Spree::Store]
        # @return [Hash, nil]
        def credentials_for(store)
          integration = integration_for(store)
          return if integration.nil?

          api_key = integration.preferred_api_key
          return if api_key.blank?

          {
            provider: provider_key,
            api_key: api_key,
            model: integration.preferred_model.presence || default_model
          }
        end
      end
    end
  end
end
