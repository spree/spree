module Spree
  module Carts
    class Create
      prepend Spree::ServiceModule::Base

      def call(user:, store:, currency: nil, locale: nil, params: {})
        return failure(:store_is_required) if store.nil?

        cart = store.carts.create!(
          user: user,
          currency: currency || store.default_currency,
          locale: locale || Spree::Current.locale
        )

        # Delegate all attribute/address/item processing to Carts::Update
        if params.present?
          result = Spree.carts_update_service.call(cart: cart, params: params)
          return result if result.failure?
        end

        success(cart.reload)
      rescue ActiveRecord::RecordNotFound
        raise
      rescue StandardError => e
        failure(nil, e.message)
      end
    end
  end
end
