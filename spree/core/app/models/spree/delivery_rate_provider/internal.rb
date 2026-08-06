module Spree
  module DeliveryRateProvider
    # Default provider: prices through the delivery method's calculator, so
    # every store that doesn't opt into an external provider behaves exactly
    # as before. Custom merchant calculators keep working unchanged, including
    # the ones that suppress a method by returning nil.
    #
    # Carries no carrier metadata and no delivery date: turning the method's
    # configured business days into a date needs a per-market holiday calendar
    # core doesn't have, and guessing one would put a wrong date in front of
    # customers. Carrier-backed providers return the real date.
    class Internal < Base
      # @param package [Spree::Stock::Package]
      # @return [Spree::DeliveryRateProvider::Estimate, nil]
      def estimate(package)
        cost = delivery_method.calculator.compute(package)
        return if cost.nil?

        Estimate.new(cost: cost)
      end
    end
  end
end
