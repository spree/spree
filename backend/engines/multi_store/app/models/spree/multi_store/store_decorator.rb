module Spree
  module MultiStore
    module StoreDecorator
      def self.prepended(base)
        base.include Spree::Store::MultiStoreMethods
        base.singleton_class.prepend Spree::Store::MultiStoreClassOverrides
      end
    end
  end

  Store.prepend(MultiStore::StoreDecorator)
  Store.prepend(Store::MultiStoreOverrides)
end
