module Spree
  module Carts
    class Update
      prepend Spree::ServiceModule::Base

      def call(cart:, params:)
        @cart = cart
        @params = params.to_h.deep_symbolize_keys
        was_in_cart = cart.cart?

        ApplicationRecord.transaction do
          assign_cart_attributes
          clear_shipping_address_if_outside_market
          assign_address(:shipping_address)
          assign_address(:billing_address)

          cart.save!

          process_items
          try_advance
          sync_stock_reservations(was_in_cart: was_in_cart)
        end

        success(cart)
      rescue ActiveRecord::RecordNotFound
        raise
      rescue ActiveRecord::RecordInvalid => e
        failure(cart, e.record.errors.full_messages.to_sentence)
      rescue StandardError => e
        failure(cart, e.message)
      end

      private

      attr_reader :cart, :params

      def address_changed?
        cart.saved_change_to_ship_address_id? || cart.saved_change_to_market_id?
      end

      def assign_cart_attributes
        cart.email = params[:email] if params[:email].present?
        cart.customer_note = params[:customer_note] if params.key?(:customer_note)

        assign_market if params[:market_id].present?
        cart.currency = params[:currency].upcase if params[:currency].present?
        cart.locale = params[:locale] if params[:locale].present?
        cart.metadata = cart.metadata.merge(params[:metadata].to_h) if params[:metadata].present?
        cart.use_shipping = params[:use_shipping] if params.key?(:use_shipping)
      end

      def assign_address(address_type)
        address_id_param = params[:"#{address_type}_id"]
        address_params = params[address_type]

        if address_id_param.present?
          address_id = resolve_address_id(address_id_param)
          cart.public_send(:"#{address_type}_id=", address_id) if address_id
          return
        end

        return unless address_params.is_a?(Hash)

        if address_params[:id].present?
          address_id = resolve_address_id(address_params[:id])
          cart.public_send(:"#{address_type}_id=", address_id) if address_id
        else
          # Only a shipping-address change invalidates delivery proposals;
          # billing updates (e.g. during payment) must not rebuild them.
          @address_invalidated = true if address_type == :shipping_address
          cart.public_send(:"#{address_type}_attributes=", address_params)
        end
      end

      def process_items
        return unless params[:items].is_a?(Array)

        result = Spree::Carts::UpsertItems.call(
          cart: cart,
          items: params[:items]
        )

        raise StandardError, result.error.to_s if result.failure?
      end

      def resolve_address_id(prefixed_id)
        return unless cart.user

        decoded = Spree::Address.decode_prefixed_id(prefixed_id)
        decoded ? cart.user.addresses.find_by(id: decoded)&.id : nil
      end

      def assign_market
        market = cart.store.markets.find_by_prefix_id!(params[:market_id])
        cart.market = market
        cart.skip_market_resolution = true
      end

      # When the market changes, clear the shipping address if its country
      # is not part of the new market. The market dictates which countries
      # are available for checkout.
      def clear_shipping_address_if_outside_market
        return unless cart.market_id_changed? && cart.ship_address&.country

        unless cart.market.country_ids.include?(cart.ship_address.country_id)
          cart.ship_address = nil
          @address_invalidated = true
        end
      end

      # Three-way dispatch on the cart→checkout transition:
      # entering checkout → Reserve, mid-checkout mutation → Extend, reverting to cart → Release.
      # A failed Reserve raises so the enclosing transaction rolls back and the
      # outer rescue surfaces the error to the API caller.
      def sync_stock_reservations(was_in_cart:)
        if cart.cart?
          Spree::StockReservations::Release.call(cart: cart) unless was_in_cart
        elsif was_in_cart
          result = Spree::StockReservations::Reserve.call(cart: cart)
          raise Spree::StockReservations::InsufficientStockError.new(nil, result.error.to_s) if result.failure?
        else
          Spree::StockReservations::Extend.call(order: cart)
        end
      end

      # Recalculation-on-write: address/market changes re-price, re-tax and
      # rebuild delivery proposals; completion stays explicit via the
      # /carts/:id/complete endpoint (a fully-covered cart must never
      # auto-complete during address updates).
      def try_advance
        return if cart.complete? || cart.canceled?

        if @address_invalidated || address_changed?
          if cart.respond_to?(:recalculate_for_address_change!)
            cart.recalculate_for_address_change!
          else
            cart.ensure_updated_fulfillments
            if cart.ship_address.present? && cart.respond_to?(:create_proposed_fulfillments)
              cart.create_proposed_fulfillments
              cart.set_fulfillments_cost
            end
            cart.recalculate_totals!
          end
        else
          cart.recalculate_totals!
        end
      rescue StandardError => e
        Rails.error.report(e, context: { order_id: cart.id }, source: 'spree.checkout')
      ensure
        # A halted transition records warnings on the cart, which reload would drop, so carry them across the reload.
        warnings = cart.warnings
        begin
          cart.reload
        rescue StandardError # rubocop:disable Lint/SuppressedException
          # reload failure must not mask the original result
        end
        cart.warnings |= warnings if warnings.present?
      end
    end
  end
end
