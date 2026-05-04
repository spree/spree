module Spree
  module Orders
    # Admin-side order creation. One-shot: customer, items, addresses, currency,
    # market, locale, notes, metadata, and a coupon code in a single call.
    # Invalid coupons are non-fatal — the order is created and `result.value`
    # carries `discount_application_errors`.
    #
    # Standalone from Spree::Carts::Create (storefront). Admin-created orders
    # are first-class Spree::Order records (status: 'draft') in 5.x and remain
    # so in 6.0 — Spree::Cart in 6.0 is storefront-only.
    class Create
      prepend Spree::ServiceModule::Base

      attr_reader :discount_application_errors

      # @param store [Spree::Store]
      # @param user [Object, nil] resolved customer (Spree.user_class instance)
      # @param params [Hash] order params (see admin API docs)
      # @return [Spree::ServiceModule::Result]
      def call(store:, user: nil, params: {})
        @store = store
        @user = user
        @params = params.to_h.deep_symbolize_keys
        @discount_application_errors = []

        return failure(:store_is_required) if store.nil?

        order = nil
        ApplicationRecord.transaction do
          order = build_order
          assign_addresses(order)
          order.tags = @params[:tags] if @params[:tags]
          order.save!

          add_items(order) if @params[:items].present?
          build_shipments(order)
          apply_coupon(order) if @params[:coupon_code].present?
          order.update_with_updater!
        end

        success(order.reload)
      rescue ActiveRecord::RecordInvalid => e
        failure(e.record, e.record.errors.full_messages.to_sentence)
      end

      private

      def build_order
        attrs = {
          user: @user,
          email: @params[:email] || @user&.email,
          currency: @params[:currency].presence&.upcase || @store.default_currency,
          locale: @params[:locale] || Spree::Current.locale,
          customer_note: @params[:customer_note],
          internal_note: @params[:internal_note],
          metadata: @params[:metadata].to_h,
          token: Spree::GenerateToken.new.call(Spree::Order),
          status: 'draft'
        }

        attrs[:market] = resolve_market if @params[:market_id].present?
        attrs.compact_blank!

        @store.orders.new(attrs)
      end

      def resolve_market
        @store.markets.find_by_prefix_id!(@params[:market_id])
      end

      def assign_addresses(order)
        if @params[:use_customer_default_address] && @user
          @user.association(:bill_address).load_target
          @user.association(:ship_address).load_target
          order.bill_address = @user.bill_address&.dup
          order.ship_address = @user.ship_address&.dup
        end

        assign_address(order, :ship_address, @params[:shipping_address_id], @params[:shipping_address])
        assign_address(order, :bill_address, @params[:billing_address_id], @params[:billing_address])
      end

      def assign_address(order, association, address_id, address_attrs)
        if address_id.present?
          address = resolve_user_address(address_id)
          order.public_send(:"#{association}_id=", address.id) if address
        elsif address_attrs.present?
          order.public_send(:"#{association}_attributes=", address_attrs)
        end
      end

      def resolve_user_address(prefixed_id)
        return unless @user

        decoded = Spree::Address.decode_prefixed_id(prefixed_id)
        decoded ? @user.addresses.find_by(id: decoded) : nil
      end

      def add_items(order)
        result = Spree::Orders::UpsertItems.call(order: order, items: @params[:items])
        raise ActiveRecord::RecordInvalid, order if result.failure?
      end

      def build_shipments(order)
        result = Spree::Orders::BuildShipments.call(order: order)
        raise ActiveRecord::RecordInvalid, order if result.failure?
      end

      def apply_coupon(order)
        order.coupon_code = @params[:coupon_code]
        handler = Spree::PromotionHandler::Coupon.new(order).apply

        if handler.successful?
          order.save!
        else
          @discount_application_errors << {
            code: handler.status_code,
            message: handler.error,
            coupon_code: @params[:coupon_code]
          }
          order.coupon_code = nil
        end
      end
    end
  end
end
