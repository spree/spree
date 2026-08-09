module Spree
  class Calculator < Spree.base_class
    # Per-currency amounts for amount-based delivery calculators, mirroring
    # how product prices work: one explicit amount per currency, no FX. The
    # `amounts` hash ({ "USD" => 5.0, "EUR" => 4.0 }) quotes the cart's
    # currency directly, so one method serves every currency it has an
    # amount for — no more method-per-currency duplication.
    #
    # The 5.x single `amount` + `currency` preferences keep working as the
    # fallback for their own currency, so upgraded stores quote unchanged
    # until they fill in the hash.
    module CurrencyAmounts
      extend ActiveSupport::Concern

      included do
        preference :amounts, :hash, default: {}
      end

      # The amount this calculator quotes for a currency: the per-currency
      # hash first, then the legacy single amount when its currency matches.
      #
      # @param currency [String]
      # @return [BigDecimal, nil] nil when the currency has no amount — the
      #   method is not offered for that cart
      def amount_for(currency)
        explicit = preferred_amounts&.transform_keys { |key| key.to_s.upcase }&.dig(currency.to_s.upcase)
        return BigDecimal(explicit.to_s) if explicit.present?

        legacy_currency = respond_to?(:preferred_currency) ? preferred_currency : nil
        return preferred_amount if legacy_currency.blank? || legacy_currency.casecmp(currency.to_s).zero?

        nil
      end

      # Whether this calculator can quote the given currency at all — the
      # Estimator's method filter, replacing the old exact-match on the
      # single currency preference.
      def supports_currency?(currency)
        amount_for(currency).present?
      end
    end
  end
end
