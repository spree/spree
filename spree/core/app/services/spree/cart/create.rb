module Spree
  module Cart
    class Create
      prepend Spree::ServiceModule::Base

      # @param user [Spree.user_class, nil] the user to associate with the cart
      # @param store [Spree::Store] the store for the cart
      # @param currency [String, nil] ISO currency code, defaults to store's default currency
      # @param locale [String, nil] locale for the cart (e.g. 'en', 'fr'), defaults to Spree::Current.locale
      # @param public_metadata [Hash] public metadata for the order
      # @param private_metadata [Hash] private metadata for the order
      # @param order_params [Hash] additional order attributes
      # @return [Spree::ServiceModule::Result]
      def call(user:, store:, currency:, locale: nil, public_metadata: {}, private_metadata: {}, order_params: {})
        order_params ||= {}

        # we cannot create an order without store
        return failure(:store_is_required) if store.nil?

        default_params = {
          user: user,
          currency: currency || store.default_currency,
          locale: locale || Spree::Current.locale,
          token: Spree::GenerateToken.new.call(Spree::Order),
          public_metadata: public_metadata.to_h,
          private_metadata: private_metadata.to_h
        }

        order = store.orders.create!(default_params.merge(order_params))
        success(order)
      end
    end
  end
end
