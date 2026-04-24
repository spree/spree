module Spree
  module CreditCards
    # @deprecated Use card.destroy directly instead. Payment cleanup is now
    #   handled by the before_destroy callback in Spree::PaymentSourceConcern.
    #   This service will be removed in Spree 6.0.
    class Destroy
      prepend Spree::ServiceModule::Base

      def call(card:)
        Spree::Deprecation.warn(
          "#{self.class.name} is deprecated and will be removed in Spree 6.0. " \
          'Use card.destroy directly instead. Payment cleanup is now handled ' \
          'automatically by the before_destroy callback in PaymentSourceConcern.',
          caller
        )

        if card.destroy
          success(card: card)
        else
          failure(card.errors.full_messages.to_sentence)
        end
      end
    end
  end
end
