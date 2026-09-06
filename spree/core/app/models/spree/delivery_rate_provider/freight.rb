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

      # What a merchant asks for up front on this shipment type, and what
      # they call the rest. A container is booked months before it sails, so
      # taking nothing at checkout is how a forwarder ends up out of pocket.
      # Nil is pay-in-full.
      #
      # Read off the method itself, so each tier can ask for a different
      # deposit — a pallet on account, a container half up front.
      #
      # @return [BigDecimal, nil]
      def deposit_percentage
        delivery_method.deposit_percentage
      end

      # @return [String, nil]
      def balance_due_label
        delivery_method.balance_due_label
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
