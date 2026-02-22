module Spree
  module MultiStore
    module PaymentMethodDecorator
      def self.prepended(base)
        base.include Spree::MultiStoreResource
      end
    end
  end

  PaymentMethod.prepend(MultiStore::PaymentMethodDecorator)
end
