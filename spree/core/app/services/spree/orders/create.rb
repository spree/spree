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
        attrs[:channel] = resolve_channel if @params[:channel_id].present?
        attrs[:preferred_stock_location] = resolve_preferred_stock_location if @params[:preferred_stock_location_id].present?
        attrs.compact_blank!

        @store.orders.new(attrs)
      end

      def resolve_market
        @store.markets.find_by_param!(@params[:market_id])
      end

      def resolve_channel
        @store.channels.find_by_param!(@params[:channel_id])
      end

      def resolve_preferred_stock_location
        Spree::StockLocation.for_store(@store).find_by_param!(@params[:preferred_stock_location_id])
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

      def resolve_user_address(address_id)
        return unless @user

        @user.addresses.find_by_param(address_id)
      end

      def add_items(order)
        result = Spree::Orders::UpsertItems.call(order: order, items: @params[:items])
        return if result.success?

        propagate_step_failure!(order, result, fallback: 'Failed to add items to order')
      end

      def build_shipments(order)
        result = Spree::Orders::BuildShipments.call(order: order)
        return if result.success?

        propagate_step_failure!(order, result, fallback: 'Failed to build shipments')
      end

      # Surface the failing record's errors on the order so the API response
      # carries an actionable message instead of an empty +processing_error+.
      # Falls back to a static message when neither the record nor the result
      # carry one — better than raising +RecordInvalid+ with an empty errors
      # collection.
      def propagate_step_failure!(order, result, fallback:)
        record = result.value
        if record.respond_to?(:errors) && record.errors.any?
          record.errors.full_messages.each { |msg| order.errors.add(:base, msg) }
        elsif result.error.to_s.present?
          order.errors.add(:base, result.error.to_s)
        else
          order.errors.add(:base, fallback)
        end
        raise ActiveRecord::RecordInvalid, order
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
