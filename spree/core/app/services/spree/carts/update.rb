module Spree
  module Carts
    class Update
      prepend Spree::ServiceModule::Base

      def call(cart:, params:)
        @cart = cart
        @params = params.to_h.deep_symbolize_keys

        ApplicationRecord.transaction do
          assign_cart_attributes
          clear_shipping_address_if_outside_market
          assign_address(:shipping_address)
          assign_address(:billing_address)

          cart.save!

          process_items
        end

        try_advance

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
          # Only revert to address state when shipping address changes.
          # Billing address updates (e.g. during payment) should not
          # destroy shipments and reset the checkout flow.
          revert_to_address_state if address_type == :shipping_address && cart.has_checkout_step?('address')
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
      end

      # When the market changes, clear the shipping address if its country
      # is not part of the new market. The market dictates which countries
      # are available for checkout.
      def clear_shipping_address_if_outside_market
        return unless cart.market_id_changed? && cart.ship_address&.country

        unless cart.market.country_ids.include?(cart.ship_address.country_id)
          cart.ship_address = nil
          revert_to_address_state if cart.has_checkout_step?('address')
        end
      end

      def revert_to_address_state
        return if ['cart', 'address'].include?(cart.state)

        cart.state = 'address'
      end

      # Auto-advance as far as the checkout state machine allows, but never
      # to complete. The complete transition must always be explicit via
      # the /carts/:id/complete endpoint — otherwise gift cards or store
      # credits that fully cover the order total would auto-complete the
      # cart during address/delivery updates.
      def try_advance
        return if cart.complete? || cart.canceled?

        steps = cart.checkout_steps
        loop do
          current_index = steps.index(cart.state).to_i
          next_step = steps[current_index + 1]
          break if next_step.nil? || next_step == 'complete'
          break unless cart.next
        end
      rescue StandardError => e
        Rails.error.report(e, context: { order_id: cart.id, state: cart.state }, source: 'spree.checkout')
      ensure
        begin
          cart.reload
        rescue StandardError # rubocop:disable Lint/SuppressedException
          # reload failure must not mask the original result
        end
      end
    end
  end
end
