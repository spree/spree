module Spree
  module Tax
    # A tax engine did not produce tax for a sale. Providers raise one of the
    # two subclasses below; core rescues this and refuses the sale rather than
    # completing one whose tax nobody computed — charging nothing because nobody
    # could be asked is the error a merchant discovers in a filing.
    #
    # Split because a customer can only act on one of them. Retrying an outage
    # may work; retrying a postcode the engine rejects never will, and telling
    # someone to try again is worse than telling them nothing.
    #
    # The parallel is {Spree::Pricing::PriceResolution::ProviderUnavailable},
    # which refuses a sale whose prices could not be confirmed. Neither is for a
    # provider a merchant switched off: that is configuration, not failure, and
    # an unconfigured engine simply has no opinion and writes no rows.
    class ProviderError < StandardError
      # @return [String, nil] which engine failed, for the report
      attr_reader :provider_key

      def initialize(message = nil, provider_key: nil)
        @provider_key = provider_key
        super(message)
      end
    end

    # The engine could not be asked — unreachable, timed out, or answering with
    # a fault of its own. Nothing is known about the tax, and trying again
    # later may well succeed, so the customer is told to retry.
    class ProviderUnavailable < ProviderError; end

    # The engine was asked and said no: an address it will not accept, a
    # misconfigured company code, a request it rejects. The service is working,
    # so retrying changes nothing — what the engine said is the useful part and
    # core passes its message on rather than inventing one.
    class CalculationRefused < ProviderError; end
  end
end
