module Spree
  module Carts
    class Create
      prepend Spree::ServiceModule::Base

      def call(params: {})
        @params = params.to_h.deep_symbolize_keys

        store = @params.delete(:store)
        return failure(:store_is_required) if store.nil?

        # Market is left to +Purchase::Market#ensure_market_presence+ when the
        # caller names none: the ambient value follows the shopper's country
        # and may be one this channel does not sell into, which the purchase's
        # own validation would then reject (docs/plans/6.0-channel-markets.md).
        cart = store.carts.create!(
          user: @params.delete(:user),
          market: @params.delete(:market),
          channel: @params.delete(:channel) || channel_for(store),
          currency: @params.delete(:currency) || store.default_currency,
          locale: @params.delete(:locale) || Spree::Current.locale
        )

        # Delegate all attribute/address/item processing to Carts::Update
        if @params.present?
          result = Spree::Carts::Update.call(cart: cart, params: @params)
          return result if result.failure?
        end

        # Items skipped during creation are reported on the cart, and reload
        # would drop them — same carry-across as Carts::Update#try_advance.
        warnings = cart.warnings
        cart.reload
        cart.warnings |= warnings if warnings.present?

        success(cart)
      rescue ActiveRecord::RecordNotFound
        raise
      rescue StandardError => e
        failure(nil, e.message)
      end

      private

      # The ambient channel belongs to whichever store the request resolved,
      # which is not necessarily the one this cart is being created in — a
      # cart must never carry another store's channel, and its market
      # validation would reject the pairing anyway.
      #
      # @param store [Spree::Store]
      # @return [Spree::Channel, nil]
      def channel_for(store)
        ambient = Spree::Current.channel
        return ambient if ambient && ambient.store_id == store.id

        store.default_channel
      end
    end
  end
end
