module Spree
  module DeliveryRateProvider
    # Quotes nothing, and says so.
    #
    # International freight is priced by a forwarder after someone looks at
    # the order — the carton count, the cubic meters, the destination port —
    # not by an API at checkout. So this provider returns a rate with no
    # price, carrying the logistics summary the merchant will send to the
    # forwarder in place of an amount.
    #
    # Which freight method a shipment is offered is
    # {Spree::DeliveryMethodRules::VolumeRule}'s job: a merchant configures
    # "Pallet" and "40ft container" as ordinary delivery methods on this
    # provider, each bounded by the cubic meters it covers.
    #
    # See docs/plans/6.0-b2b-wholesale-shipping.md.
    class Freight < Base
      # There is no price to calculate, so the method's calculator is never
      # consulted and admin UIs hide its pricing form.
      def self.uses_calculator?
        false
      end

      # Freight ships to an address like any carrier does.
      def self.requires_address?
        true
      end

      # @param package [Spree::Stock::Package]
      # @return [Spree::DeliveryRateProvider::Estimate]
      def estimate(package)
        Estimate.new(
          cost: 0,
          unpriced: true,
          name: delivery_method.name,
          metadata: { 'freight_summary' => package.freight_summary.as_json }
        )
      end
    end
  end
end
