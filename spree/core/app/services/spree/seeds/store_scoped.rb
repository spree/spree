module Spree
  module Seeds
    # Shared entry point for seeds whose rows belong to a store. Including
    # classes implement a private `seed(store)` that seeds exactly one store
    # and is safe to re-run.
    module StoreScoped
      # @param store [Spree::Store, nil] the store to seed; every store when nil
      def call(store: nil)
        return seed(store) if store

        Spree::Store.find_each { |each_store| seed(each_store) }
      end
    end
  end
end
