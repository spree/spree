module Spree
  module MultiStore
    module PromotionDecorator
      def self.prepended(base)
        base.include Spree::MultiStoreResource
      end
    end
  end

  Promotion.prepend(MultiStore::PromotionDecorator)
end
