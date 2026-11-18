module Spree
  module Integrations
    # Shared behaviour for the AI vendor credential cards.
    #
    # One subclass per vendor, so each gets its own card in the integrations
    # gallery and is connected independently — which vendor a store actually
    # talks to is the `assistant_provider` store preference.
    class AiProvider < Spree::Integration
      preference :api_key, :password
      # Blank means "whatever the provider ships as its default", so a merchant
      # who does not care never has to know a model name.
      preference :model, :string

      def self.integration_group
        'ai'
      end

      # The provider class this card supplies credentials for.
      #
      # @return [Class<Spree::AssistantProvider::Base>]
      def self.assistant_provider_class
        raise NotImplementedError, 'AI integrations must name their provider class'
      end

      # Proves the key authenticates, by asking the vendor for the cheapest
      # thing it will answer: a one-token completion. Runs only when the
      # merchant flips the card active — saving credentials never calls out.
      #
      # @return [Boolean]
      def can_connect?
        self.connection_error_message = nil

        if preferred_api_key.blank?
          self.connection_error_message = I18n.t('spree.assistant.errors.api_key_missing')
          return false
        end

        Spree::Assistant::VerifyCredentials.call(
          provider_class: self.class.assistant_provider_class,
          api_key: preferred_api_key,
          model: preferred_model.presence || self.class.assistant_provider_class.default_model
        )
        true
      rescue StandardError => e
        self.connection_error_message = e.message
        false
      end
    end
  end
end
