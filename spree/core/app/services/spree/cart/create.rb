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
      # @param line_items [Array<Hash>] line items to add, each with :variant_id (prefixed) and :quantity
      # @return [Spree::ServiceModule::Result]
      def call(user:, store:, currency:, locale: nil, metadata: {}, public_metadata: {}, private_metadata: {}, order_params: {}, line_items: [])
        order_params ||= {}
        line_items ||= []

        # we cannot create an order without store
        return failure(:store_is_required) if store.nil?

        resolved_metadata = metadata.presence || private_metadata

        default_params = {
          user: user,
          currency: currency || store.default_currency,
          locale: locale || Spree::Current.locale,
          token: Spree::GenerateToken.new.call(Spree::Order),
          public_metadata: public_metadata.to_h,
          private_metadata: resolved_metadata.to_h
        }

        order = nil

        ApplicationRecord.transaction do
          order = store.orders.create!(default_params.merge(order_params))

          if line_items.present?
            result = Spree.cart_upsert_items_service.call(order: order, line_items: line_items)
            raise StandardError, result.error.to_s if result.failure?
          end
        end

        success(order)
      rescue ActiveRecord::RecordNotFound
        raise
      rescue StandardError => e
        failure(order, e.message)
      end
    end
  end
end
