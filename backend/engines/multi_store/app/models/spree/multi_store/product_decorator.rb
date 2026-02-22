module Spree
  module MultiStore
    module ProductDecorator
      def self.prepended(base)
        base.include Spree::MultiStoreResource
      end
    end
  end

  Product.prepend(MultiStore::ProductDecorator)
end
