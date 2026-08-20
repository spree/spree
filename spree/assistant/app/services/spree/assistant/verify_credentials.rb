module Spree
  module Assistant
    # Proves a vendor key works, by asking for the smallest completion the
    # vendor will answer. Used by verify-before-activate on the integration
    # cards, so a merchant learns a key is wrong while saving it rather than
    # mid-conversation.
    class VerifyCredentials
      class << self
        # @param provider_class [Class<Spree::AssistantProvider::Base>]
        # @param api_key [String]
        # @param model [String]
        # @raise [StandardError] whatever the vendor raised, for the card to show
        # @return [true]
        def call(provider_class:, api_key:, model:)
          chat = Spree::Assistant::ChatBuilder.build(
            provider_key: provider_class.provider_key,
            api_key: api_key,
            model: model
          )

          chat.with_temperature(0).ask('Reply with the single word: ok')
          true
        end
      end
    end
  end
end
