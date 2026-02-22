module Spree
  module Orders
    class Sort < ::Spree::BaseSorter
      def initialize(*args)
        Spree::Deprecation.warn('Spree::Orders::Sort is deprecated and will be removed in Spree 5.5.')
        super
      end
    end
  end
end
