module Spree
  module SampleData
    # @deprecated Raised by the Ruby sample data loader, which loads nothing
    #   since Spree 6.1. Will be removed in Spree 6.2.
    class StoreNotProvisioned < StandardError; end
  end
end
