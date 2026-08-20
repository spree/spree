module Spree
  module AssistantProvider
    class Gemini < Base
      DEFAULT_MODEL = 'gemini-2.0-flash'.freeze

      class << self
        def display_name
          'Google Gemini'
        end

        def provider_key
          :gemini
        end

        def integration_class
          'Spree::Integrations::Gemini'
        end

        def default_model
          DEFAULT_MODEL
        end
      end
    end
  end
end
