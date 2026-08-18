# frozen_string_literal: true

module Spree
  module Commissions
    # How a commission is taxed — the rate, and the treatment behind it.
    #
    # This is tax on the marketplace's own service to the seller, not on the
    # goods the customer bought — a separate supply with its own place of
    # taxation, which is why it is asked against the **seller's billing
    # address** rather than wherever the parcel went.
    #
    # Precedence: an explicit override on the rate, else the sale's tax engine,
    # else the store's default. A provider with no opinion returns nil rather
    # than zero, so silence falls through to the default instead of being read
    # as "this fee is untaxed".
    #
    # The treatment is only as good as its source: an operator override or a
    # store default is a number someone typed, so it is recorded as standard
    # rated without inventing a jurisdiction for it. Only the tax engine knows
    # where it taxed the fee.
    #
    # Swap through +Spree.commissions_resolve_tax_rate_service+.
    class ResolveTaxRate
      prepend Spree::ServiceModule::Base

      # @param rate [Spree::CommissionRate]
      # @param seller [Spree::Seller] the seller being invoiced
      # @param order [Spree::Order]
      # @return [Spree::CommissionTax]
      def call(rate:, seller:, order:)
        return success(configured(rate.commission_tax_rate)) if rate.commission_tax_rate.present?

        from_provider = provider_tax(seller: seller, order: order)
        return success(from_provider) if from_provider

        success(configured(order.store.preferred_default_commission_tax_rate))
      end

      private

      # A rate somebody configured. Standard rated by definition — nobody
      # types a number to mean "exempt" — and carrying no jurisdiction, because
      # a store preference does not know one.
      def configured(value)
        amount = value.to_d

        Spree::CommissionTax.new(
          rate: amount,
          taxability_reason: amount.zero? ? nil : 'standard_rated'
        )
      end

      # Commission is written while an order is being placed, so a tax service
      # being unreachable must never cost the marketplace a checkout: the error
      # is reported and the configured default applies.
      def provider_tax(seller:, order:)
        address = seller.billing_address
        amount = order.tax_provider.service_tax_rate(address: address, store: order.store)
        return nil if amount.blank?

        Spree::CommissionTax.new(
          rate: amount.to_d,
          taxability_reason: amount.to_d.zero? ? 'zero_rated' : 'standard_rated',
          country_code: address&.country_code,
          state_code: address&.state_code
        )
      rescue StandardError => error
        Rails.error.report(
          error,
          handled: true,
          context: { seller_id: seller.id, order_id: order.id },
          source: 'spree.core'
        )
        nil
      end
    end
  end
end
