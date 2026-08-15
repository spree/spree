module Spree
  module Carts
    class Update
      prepend Spree::ServiceModule::Base

      def call(cart:, params:)
        @cart = cart
        @params = params.to_h.deep_symbolize_keys
        was_in_checkout = cart.in_checkout?

        ApplicationRecord.transaction do
          assign_cart_attributes
          clear_shipping_address_if_outside_market
          assign_address(:shipping_address)
          assign_address(:billing_address)
          assign_default_addresses

          cart.save!

          process_items
          try_advance
          sync_stock_reservations(was_in_checkout: was_in_checkout)
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

      # Pickup intent counts as a destination change: proposals priced for
      # shipping (or for another counter) are stale once the customer picks
      # or clears a pickup location.
      def destination_changed?
        cart.saved_change_to_ship_address_id? ||
          cart.saved_change_to_market_id? ||
          cart.saved_change_to_preferred_stock_location_id?
      end

      def assign_cart_attributes
        cart.email = params[:email] if params[:email].present?
        cart.customer_note = params[:customer_note] if params.key?(:customer_note)

        assign_market if params[:market_id].present?
        cart.currency = params[:currency].upcase if params[:currency].present?
        cart.locale = params[:locale] if params[:locale].present?
        cart.metadata = cart.metadata.merge(params[:metadata].to_h) if params[:metadata].present?
        cart.use_shipping = params[:use_shipping] if params.key?(:use_shipping)
        assign_preferred_stock_location if params.key?(:preferred_stock_location_id)
      end

      # Storefront pickup selection: resolves the public prefixed ID (or raw
      # ID) against the store's pickup-enabled locations, intersected with
      # the channel's served set — a counter the channel cannot fulfill from
      # 404s exactly like a non-pickup one. Enforced here at the API boundary,
      # mirroring Orders::Create.
      def assign_preferred_stock_location
        value = params[:preferred_stock_location_id]

        if value.blank?
          cart.preferred_stock_location_id = nil
          return
        end

        eligible = cart.store.stock_locations.pickup_enabled
        eligible = eligible.merge(cart.channel.served_stock_locations) if cart.channel
        cart.preferred_stock_location_id = eligible.find_by_param!(value).id
      end

      def assign_address(address_type)
        address_id_param = params[:"#{address_type}_id"]
        return resolve_and_assign(address_type, address_id_param) if address_id_param.present?

        address_params = params[address_type]
        return unless address_params.is_a?(Hash)

        if address_params[:id].present?
          resolve_and_assign(address_type, address_params[:id])
        else
          with_address_recalc_tracking(address_type) do
            cart.public_send(:"#{address_type}_attributes=", address_params)
          end
        end
      end

      def resolve_and_assign(address_type, prefixed_id)
        address_id = resolve_address_id(prefixed_id)
        assign_address_id(address_type, address_id) if address_id
      end

      def assign_address_id(address_type, address_id)
        return if cart.public_send(:"#{address_type}_id") == address_id

        with_address_recalc_tracking(address_type) do
          cart.public_send(:"#{address_type}_id=", address_id)
        end
      end

      def with_address_recalc_tracking(address_type)
        tax_address_was = cart.tax_address
        yield

        # Shipping changes always affect delivery proposals; billing changes only
        # matter when they shift which address computes tax.
        @address_invalidated = true if address_type == :shipping_address || cart.tax_address != tax_address_was
      end

      def process_items
        return unless params[:items].is_a?(Array)

        result = Spree.cart_upsert_items_workflow.call(cart: cart, items: params[:items])

        raise StandardError, result.error.to_s if result.failure?
      end

      # Legacy `before_transition to: :address` parity: once a signed-in
      # customer is in checkout, blank address slots fill from their saved
      # defaults (assign_default_addresses! guards each slot itself).
      def assign_default_addresses
        return unless cart.customer
        return unless cart.email.present? || cart.ship_address_id.present?

        cart.assign_default_addresses!
      end

      def resolve_address_id(prefixed_id)
        return unless cart.customer

        decoded = Spree::Address.decode_prefixed_id(prefixed_id)
        decoded ? cart.customer.addresses.find_by(id: decoded)&.id : nil
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
        return unless cart.market_id_changed? && cart.ship_address&.country_code.present?

        unless cart.market.country_codes.include?(cart.ship_address.country_code)
          cart.ship_address = nil
          @address_invalidated = true
        end
      end

      # Three-way dispatch on the cart→checkout transition:
      # entering checkout → Reserve, mid-checkout mutation → Extend, reverting to cart → Release.
      # A failed Reserve raises so the enclosing transaction rolls back and the
      # outer rescue surfaces the error to the API caller.
      def sync_stock_reservations(was_in_checkout:)
        if !cart.in_checkout?
          Spree::StockReservations::Release.call(cart: cart) if was_in_checkout
        elsif was_in_checkout
          Spree::StockReservations::Extend.call(cart: cart)
        else
          result = Spree::StockReservations::Reserve.call(cart: cart)
          raise Spree::StockReservations::InsufficientStockError.new(nil, result.error.to_s) if result.failure?
        end
      end

      # Recalculation-on-write: address/market changes re-price, re-tax and
      # rebuild delivery proposals; completion stays explicit via the
      # /carts/:id/complete endpoint (a fully-covered cart must never
      # auto-complete during address updates).
      def try_advance
        return if cart.complete?

        if @address_invalidated || destination_changed?
          cart.recalculate_for_address_change!
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
