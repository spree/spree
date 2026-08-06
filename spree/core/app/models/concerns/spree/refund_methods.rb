module Spree
  # The ways money goes back to a customer on a post-sale record.
  #
  # A closed set, unlike claim types: each value picks a different code path —
  # `store_credit` is an internal ledger write inside the status transaction,
  # `original_payment` is a gateway call outside it. An unrecognised value
  # would otherwise fall through the `internal_refund?` branch to the gateway,
  # moving money by a route the caller did not ask for, so the workflows that
  # accept one reject anything not listed here.
  module RefundMethods
    METHODS = %w[original_payment store_credit].freeze

    # @param value [String, Symbol, nil]
    # @return [Boolean]
    def self.valid?(value)
      METHODS.include?(value.to_s)
    end
  end
end
