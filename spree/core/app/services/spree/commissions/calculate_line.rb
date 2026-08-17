# frozen_string_literal: true

module Spree
  module Commissions
    # Works out what one commission line is worth, and builds it.
    #
    # Two amounts, computed independently, because they are two different
    # supplies. `amount` is the platform's fee, charged on what the seller sold.
    # `tax_amount` is VAT on that fee — the marketplace's own taxable service to
    # the seller, which is why it is applied *on top* rather than taken out of
    # the item's own VAT. Keeping them apart is what lets a marketplace invoice
    # its commission properly in the EU, and it is the reason the base defaults
    # to the seller's **net** price: mixing the consumer's VAT into the fee base
    # would tax the same money twice under two different regimes.
    #
    # The returned record is not saved — the caller persists it inside whatever
    # transaction is placing the order.
    #
    # Swap through +Spree.commissions_calculate_line_service+.
    class CalculateLine
      prepend Spree::ServiceModule::Base

      # @param rate [Spree::CommissionRate] the resolved rate
      # @param vendor [Spree::Vendor] the seller being charged
      # @param order [Spree::Order]
      # @param line_item [Spree::LineItem, nil] the commissioned item…
      # @param fulfillment [Spree::Fulfillment, nil] …or the commissioned delivery
      # @param commission_tax [Spree::CommissionTax, nil] pre-resolved tax
      #   treatment, so commissioning a whole order resolves it once
      # @return [Spree::CommissionLine] unsaved
      def call(rate:, vendor:, order:, line_item: nil, fulfillment: nil, commission_tax: nil)
        # Exactly one, checked here rather than left to the record's own
        # validation: passing both would otherwise quietly commission the item
        # and drop the delivery, and only fail on save.
        subjects = [line_item, fulfillment].compact
        unless subjects.one?
          return failure(nil, 'a commission line needs exactly one of a line item or a fulfillment')
        end

        subject = subjects.first
        currency = order.currency
        precision = Spree::Money::Rounding.precision(currency)
        tax = commission_tax || resolve_tax(rate: rate, vendor: vendor, order: order)

        amount = Spree::Money::Rounding.quantize(charge_for(rate, subject, currency), precision)
        tax_amount = Spree::Money::Rounding.quantize(amount * tax.rate, precision)

        success(
          Spree::CommissionLine.new(
            order: order,
            vendor: vendor,
            line_item: line_item,
            fulfillment: fulfillment,
            commission_rate: rate,
            kind: rate.kind,
            rate: rate.value,
            amount: amount,
            tax_amount: tax_amount,
            # Summed from the two rounded parts rather than rounded again, so a
            # marketplace's ledger reconciles with its payouts to the cent.
            total: amount + tax_amount,
            currency: currency,
            **tax.to_line_attributes
          )
        )
      end

      # The seller's own revenue on this row, net of VAT unless the rate opts
      # into a gross base. Discounts come off either way — `taxable_basis` is
      # already the discounted, never-negative figure both line items and
      # fulfillments agree on — because commission is charged on what the
      # customer actually paid, and a promotion is the seller's concession in v1.
      #
      # Which VAT column matters depends on how the store prices: a
      # tax-inclusive price carries VAT inside it, which a net base removes,
      # while a tax-exclusive one carries none, so only a gross base adds any.
      #
      # A class method because a value band has to weigh the sale exactly as
      # the fee will (Spree::Commissions::Context#commission_basis) — if the
      # two ever computed it differently, a band would admit sales the fee then
      # charged as though they were worth something else.
      #
      # @param rate [Spree::CommissionRate, nil]
      # @param subject [Spree::LineItem, Spree::Fulfillment]
      # @return [BigDecimal]
      def self.base_for(rate, subject)
        basis = subject.taxable_basis

        base = if rate&.tax_inclusive?
                 basis + subject.additional_tax_total.to_d
               else
                 basis - subject.included_tax_total.to_d
               end

        [base, BigDecimal(0)].max
      end

      private

      # A fixed rate is a flat fee for the sale, charged once however many units
      # it covered — quantity is what a percentage already accounts for through
      # the base.
      def charge_for(rate, subject, currency)
        # A flat fee is charged in the sale's own currency; the rate only got
        # this far because it states an amount there.
        return clamp(rate, rate.amount_for(currency).to_d) if rate.fixed?

        clamp(rate, self.class.base_for(rate, subject) * rate.value / 100)
      end

      def clamp(rate, amount)
        amount = [amount, rate.min_amount].max if rate.min_amount.present?
        amount = [amount, rate.max_amount].min if rate.max_amount.present?
        amount
      end

      def resolve_tax(rate:, vendor:, order:)
        Spree.commissions_resolve_tax_rate_service.call(rate: rate, vendor: vendor, order: order).value
      end
    end
  end
end
