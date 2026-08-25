module Spree
  module Carts
    # Asks the store's inventory source whether these items can actually be
    # supplied.
    #
    # Runs outside any transaction, as an +external_step+: the provider may be
    # an external warehouse system, and holding a transaction open across that
    # call is what turns a slow warehouse into stuck locks.
    #
    # The provider only supplies the *rows*; {Spree::Stock::Quantifier} still
    # does the arithmetic over them, so backorder limits, preorders and local
    # checkout holds behave identically whoever owns the stock figure.
    class CheckAvailability
      prepend ::Spree::ServiceModule::Base

      # @param cart [Spree::Cart, Spree::Order]
      # @param items [Array<Hash>] +[{ variant:, quantity: }]+ to check
      # @return [Spree::ServiceModule::Result] value is an array of
      #   +[variant, requested_quantity]+ pairs that cannot be supplied
      def call(cart:, items:)
        entries = Array(items).filter_map do |item|
          item = item.to_h.symbolize_keys
          variant = item[:variant]
          next if variant.blank?

          [variant, item[:quantity].to_i]
        end
        return success([]) if entries.empty?

        @cart = cart
        @provider = cart&.store&.inventory_provider_instance
        return success([]) if @provider.blank?

        @internal = @provider.is_a?(Spree::InventoryProvider::Internal)

        unsupplyable = entries.reject { |variant, quantity| supplyable?(variant, quantity) }

        success(unsupplyable)
      rescue StandardError => e
        handle_failure(e, cart: cart)
      end

      private

      def supplyable?(variant, quantity)
        stock_levels = @internal ? nil : @provider.stock_levels_for(variant)

        Spree::Stock::Quantifier.new(variant, excluded_order: @cart, stock_levels: stock_levels).
          can_supply?(quantity)
      end

      def handle_failure(error, cart:)
        raise error if error.is_a?(Spree::ServiceModule::ResultError)

        store = cart&.store
        policy = store&.inventory_failure_policy
        Spree::ProviderFailurePolicy.report_fallback(
          kind: 'inventory', provider: @provider&.class&.key,
          store: store, error: error,
          policy: policy || Spree::ProviderFailurePolicy::DEFAULT_INVENTORY_POLICY
        )

        # Strict stores would rather refuse than sell on a figure they cannot
        # confirm; the default is to trust the local snapshot, since an
        # oversell is recoverable and a blocked checkout is not.
        return failure(cart, error.message) if policy == 'strict'

        success([])
      end
    end
  end
end
