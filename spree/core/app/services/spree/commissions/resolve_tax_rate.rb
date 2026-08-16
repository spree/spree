# frozen_string_literal: true

module Spree
  module Commissions
    # The VAT charged on a commission, as a fraction.
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
    # Swap through +Spree.commissions_resolve_tax_rate_service+.
    class ResolveTaxRate
      prepend Spree::ServiceModule::Base

      # @param rate [Spree::CommissionRate]
      # @param vendor [Spree::Vendor] the seller being invoiced
      # @param order [Spree::Order]
      # @return [BigDecimal] e.g. 0.21 for 21%
      def call(rate:, vendor:, order:)
        return success(rate.commission_tax_rate.to_d) if rate.commission_tax_rate.present?

        from_provider = provider_rate(vendor: vendor, order: order)
        return success(from_provider.to_d) if from_provider.present?

        success(order.store.preferred_default_commission_tax_rate.to_d)
      end

      private

      # Commission is written while an order is being placed, so a tax service
      # being unreachable must never cost the marketplace a checkout: the error
      # is reported and the configured default applies.
      def provider_rate(vendor:, order:)
        order.tax_provider.service_tax_rate(address: vendor.billing_address, store: order.store)
      rescue StandardError => error
        Rails.error.report(
          error,
          handled: true,
          context: { vendor_id: vendor.id, order_id: order.id },
          source: 'spree.core'
        )
        nil
      end
    end
  end
end
