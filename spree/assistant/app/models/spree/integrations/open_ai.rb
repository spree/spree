module Spree
  module Integrations
    class OpenAI < AiProvider
      def self.assistant_provider_class
        Spree::AssistantProvider::OpenAI
      end

      def self.integration_name
        'OpenAI'
      end

      def self.description
        'Run the dashboard assistant on OpenAI models.'
      end
    end
  end
end
