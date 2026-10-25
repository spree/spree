# frozen_string_literal: true

module Spree
  module Refunds
    # The tax half of putting money back: asking the order's tax provider what
    # tax goes back with it, and filing the credit once the money has moved.
    #
    # Shared by returns, claims and exchanges, which give back tax for the same
    # reason they give back money (see Spree::PostSale::Taxation).
    module TaxCredit
      extend ActiveSupport::Concern

      private

      # Runs a provider calculation, refusing the step when the provider could
      # not answer. Going on would refund tax nobody worked out — too little,
      # and the customer is short; none, and the merchant finds out in a filing.
      def with_tax_provider(record)
        yield
      rescue Spree::Tax::ProviderError => error
        Rails.error.report(error, handled: true, context: tax_report_context(record), source: 'spree.post_sale')

        # A refusal names its own problem; an outage is worth retrying, and its
        # raw message names the endpoint rather than anything the caller can fix.
        failure(record, error.is_a?(Spree::Tax::CalculationRefused) ? error.message.to_s : :tax_provider_unavailable)
      end

      # A record withdrawn before anything went back loses its rows — left in
      # place they would count against what a later return of the same units
      # may credit.
      def clear_tax_credit(record)
        record.clear_tax!
      end

      # Files the credit with the provider after the money has moved.
      # Reported rather than raised: the refund has gone through and the record
      # is already settled, so failing here would fail a refund that happened.
      def file_tax_credit(record, lines, amount)
        order = record.order
        order.tax_provider.refund(order, lines, amount: amount, tax_date: order.completed_at)
      rescue Spree::Tax::ProviderError => error
        Rails.error.report(error, handled: true, context: tax_report_context(record), source: 'spree.post_sale')
      end

      # Divides a refund across lines in proportion to what each is worth, to
      # the cent, so the tax given back on each line follows the money on it.
      #
      # @param amount [BigDecimal]
      # @param worth [Hash{Object => BigDecimal}] line => what it is worth
      # @param currency [String]
      # @return [Hash{Object => BigDecimal}]
      def allocate_refund(amount, worth, currency)
        weights = worth.values.map { |value| Spree::Money::Rounding.to_minor_units(value, currency) }
        return worth.transform_values { 0.to_d } if weights.sum.zero?

        shares = Spree::Adjusters::LargestRemainder.largest_remainder_shares(
          Spree::Money::Rounding.to_minor_units(amount, currency), weights
        )
        worth.keys.zip(shares).to_h { |line, cents| [line, Spree::Money::Rounding.from_minor_units(cents, currency)] }
      end

      def tax_report_context(record)
        { record_type: record.class.name, record_id: record.id, order_id: record.order_id }
      end
    end
  end
end
