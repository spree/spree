module Spree
  module Integrations
    class Gemini < AiProvider
      def self.assistant_provider_class
        Spree::AssistantProvider::Gemini
      end

      def self.integration_name
        'Google Gemini'
      end

      def self.description
        'Run the dashboard assistant on Google Gemini models.'
      end
    end
  end
end
