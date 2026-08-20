module Spree
  module AssistantProvider
    # Claude — the default the assistant ships with.
    class Anthropic < Base
      # Claude's tool use is what the approval gate depends on, so this is the
      # provider the assistant is tuned against.
      DEFAULT_MODEL = 'claude-sonnet-4-5'.freeze

      class << self
        def display_name
          'Anthropic (Claude)'
        end

        def provider_key
          :anthropic
        end

        def integration_class
          'Spree::Integrations::Anthropic'
        end

        def default_model
          DEFAULT_MODEL
        end
      end
    end
  end
end
