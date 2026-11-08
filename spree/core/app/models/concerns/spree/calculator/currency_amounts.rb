module Spree
  class Calculator < Spree.base_class
    # Per-currency amounts for amount-based delivery calculators, mirroring
    # how product prices work: one explicit amount per currency, no FX. The
    # `amounts` hash ({ "USD" => 5.0, "EUR" => 4.0 }) quotes the cart's
    # currency directly, so one method serves every currency it has an
    # amount for — no more method-per-currency duplication.
    #
    # Once the hash holds an amount it alone decides, and a currency it leaves
    # out is not offered. The 5.x single `amount` + `currency` pair quotes its
    # own currency only while the hash is empty, so upgraded stores quote
    # unchanged until they fill it in. The pair's untouched default (0 in the
    # store's currency) can never be read as a price someone set beside the
    # hash.
    module CurrencyAmounts
      extend ActiveSupport::Concern

      included do
        preference :amounts, :hash, keys: :currency, values: :money, default: {}
      end

      # The amount this calculator quotes for a currency: the per-currency
      # hash when it holds any amount, otherwise the legacy single amount for
      # its own currency.
      #
      # @param currency [String]
      # @return [BigDecimal, nil] nil when the currency has no amount — the
      #   method is not offered for that cart
      def amount_for(currency)
        amounts = currency_amounts
        return amounts[currency.to_s.upcase] if amounts.any?

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

      private

      # The hash's amounts by upper-case currency, without blank entries.
      def currency_amounts
        (preferred_amounts || {}).each_with_object({}) do |(key, value), amounts|
          amounts[key.to_s.upcase] = BigDecimal(value.to_s) if value.present?
        end
      end
    end
  end
end
