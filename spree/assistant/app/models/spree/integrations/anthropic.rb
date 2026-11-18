module Spree
  module Integrations
    # Claude credentials — the assistant's default vendor.
    class Anthropic < AiProvider
      def self.assistant_provider_class
        Spree::AssistantProvider::Anthropic
      end

      def self.integration_name
        'Anthropic (Claude)'
      end

      def self.description
        'Run the dashboard assistant on Claude.'
      end
    end
  end
end
