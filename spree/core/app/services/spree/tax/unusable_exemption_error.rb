module Spree
  module Tax
    # Raised for reporting when an exemption reaches core in a state that would
    # widen rather than narrow a claim. Reported, never raised at the customer:
    # the sale continues with tax charged.
    class UnusableExemptionError < StandardError; end
  end
end
