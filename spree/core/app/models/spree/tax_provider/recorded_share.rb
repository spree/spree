module Spree
  module TaxProvider
    # The tax a return, claim or exchange line gives back, read off what the
    # sale actually charged: each credited unit's part of every TaxLine on the
    # original line, row by row.
    #
    # Read from the rows rather than recomputed from TaxRate configuration,
    # because the customer is owed back what they paid. Rates are not
    # versioned, so a rate edited since the sale would otherwise refund a
    # figure nobody was charged.
    #
    # Internal's answer to +estimate_refund+. Public so any other provider can
    # answer with it too, rather than quoting the credit itself.
    class RecordedShare
      # @param order [Spree::Order]
      # @param items [Array<Spree::ReturnLineItem, Spree::ClaimLineItem, Spree::ExchangeLineItem>]
      # @param amounts [Hash{Object => BigDecimal}, nil] see Base#estimate_refund
      def initialize(order:, items:, amounts: nil)
        @order = order
        @items = Array(items)
        @amounts = amounts
      end

      # Replaces each item's credit rows.
      #
      # @return [void]
      def call
        items.each do |item|
          key = Spree::TaxLine.adjustable_key_for(item.class)
          Spree::TaxLine.credits.where(key => item.id).delete_all
          credit(item, key)
        end
      end

      private

      attr_reader :order, :items, :amounts

      def credit(item, key)
        share = share_of_line(item)
        return if share.zero?

        sources = item.line_item.tax_lines.order(:id).to_a
        sources.zip(shares_for(sources, share)).each do |source, cents|
          write(item, key, source, cents)
        end
      end

      # The part of the original line this item gives back: its credited units,
      # and of those only the share of their worth the customer is refunded.
      def share_of_line(item)
        quantity = item.line_item&.quantity.to_i
        units = item.credited_quantity.to_i
        return 0 if quantity.zero? || units.zero?

        Rational(units, quantity) * refunded_fraction(item)
      end

      def refunded_fraction(item)
        return 1 if amounts.nil?

        worth = item.credited_worth.to_d
        return 0 unless worth.positive?

        [Rational(amounts.fetch(item, 0).to_d) / Rational(worth), 1].min
      end

      # The rows' total share rounded once, then divided by largest remainder,
      # so the credit lands on the cent and each rate keeps its part of it. A
      # row is never credited past what earlier credits left of it, or three
      # single-unit returns of one line could give back a cent more than it
      # charged.
      def shares_for(sources, share)
        weights = sources.map { |source| to_minor_units(source.amount) }
        return Array.new(sources.size, 0) if weights.sum.zero?

        target = (Rational(weights.sum) * share).round(half: :up)
        allotted = Spree::Adjusters::LargestRemainder.largest_remainder_shares(target, weights)

        sources.zip(allotted).map { |source, cents| [cents, remaining_cents(source)].min }
      end

      def remaining_cents(source)
        credited = Spree::TaxLine.credits.where(original_tax_line_id: source.id).sum(:amount)
        [to_minor_units(source.amount) - to_minor_units(credited), 0].max
      end

      # Zero-amount rows are copied too: a zero-rated or exempt sale is a
      # treatment the credit note has to repeat.
      def write(item, key, source, cents)
        Spree::TaxLine.create!(
          key => item.id,
          order: order,
          credit: true,
          original_tax_line: source,
          tax_rate_id: source.tax_rate_id,
          amount: Spree::Money::Rounding.from_minor_units(cents, order.currency),
          rate: source.rate,
          label: source.label,
          included: source.included,
          provider_id: source.provider_id,
          taxability_reason: source.taxability_reason,
          country_code: source.country_code,
          state_code: source.state_code,
          data: source.data
        )
      end

      def to_minor_units(amount)
        Spree::Money::Rounding.to_minor_units(amount, order.currency)
      end
    end
  end
end
