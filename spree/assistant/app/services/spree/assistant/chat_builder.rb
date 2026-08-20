module Spree
  module Assistant
    # Builds a RubyLLM chat bound to one store's credentials.
    #
    # Credentials are scoped per call rather than set globally, so two stores in
    # the same process never share a key.
    class ChatBuilder
      class << self
        # @param provider_key [Symbol] e.g. :anthropic
        # @param api_key [String]
        # @param model [String]
        # @return [RubyLLM::Chat]
        def build(provider_key:, api_key:, model:)
          context = ::RubyLLM.context do |config|
            config.public_send(:"#{provider_key}_api_key=", api_key)
            config.request_timeout = REQUEST_TIMEOUT_SECONDS
          end

          context.chat(model: model, provider: provider_key, assume_model_exists: true)
        end
      end

      # Long enough for a thinking model on a hard question, short enough that a
      # wedged request cannot hold a web thread indefinitely.
      REQUEST_TIMEOUT_SECONDS = 120
    end
  end
end
