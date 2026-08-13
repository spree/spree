module Spree
  module Carts
    class Create
      prepend Spree::ServiceModule::Base

      def call(params: {})
        @params = params.to_h.deep_symbolize_keys

        store = @params.delete(:store)
        return failure(:store_is_required) if store.nil?

        cart = store.carts.create!(
          user: @params.delete(:user),
          market: @params.delete(:market) || Spree::Current.market,
          channel: @params.delete(:channel) || Spree::Current.channel,
          currency: @params.delete(:currency) || store.default_currency,
          locale: @params.delete(:locale) || Spree::Current.locale
        )

        # Delegate all attribute/address/item processing to Carts::Update
        if @params.present?
          update = Spree::Carts::Update.new
          result = update.call(cart: cart, params: @params)
          return result if result.failure?

          @item_warnings = update.item_warnings
        end

        success(cart.reload)
      rescue ActiveRecord::RecordNotFound
        raise
      rescue StandardError => e
        failure(nil, e.message)
      end

      # Items the batch did not apply — see Spree::Carts::Update#item_warnings.
      #
      # @return [Array<Spree::Carts::ItemWarning>]
      def item_warnings
        @item_warnings ||= []
      end
    end
  end
end
