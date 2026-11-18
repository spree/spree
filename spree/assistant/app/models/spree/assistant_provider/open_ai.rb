module Spree
  module AssistantProvider
    class OpenAI < Base
      DEFAULT_MODEL = 'gpt-4o'.freeze

      class << self
        def display_name
          'OpenAI'
        end

        def provider_key
          :openai
        end

        def integration_class
          'Spree::Integrations::OpenAI'
        end

        def default_model
          DEFAULT_MODEL
        end
      end
    end
  end
end
