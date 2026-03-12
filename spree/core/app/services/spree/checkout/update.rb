module Spree
  module Checkout
    class Update
      prepend Spree::ServiceModule::Base

      def call(order:, params:)
        @order = order
        @params = params.to_h.deep_symbolize_keys

        ApplicationRecord.transaction do
          assign_order_attributes
          assign_address(:ship_address)
          assign_address(:bill_address)

          order.save!

          process_line_items
        end

        try_advance

        success(order)
      rescue ActiveRecord::RecordNotFound
        raise
      rescue ActiveRecord::RecordInvalid => e
        failure(order, e.record.errors.full_messages.to_sentence)
      rescue StandardError => e
        failure(order, e.message)
      end

      private

      attr_reader :order, :params

      def assign_order_attributes
        order.email = params[:email] if params[:email].present?
        order.special_instructions = params[:special_instructions] if params.key?(:special_instructions)
        order.currency = params[:currency].upcase if params[:currency].present?
        order.locale = params[:locale] if params[:locale].present?
        order.metadata = order.metadata.merge(params[:metadata].to_h) if params[:metadata].present?
      end

      def assign_address(address_type)
        address_id_param = params[:"#{address_type}_id"]
        address_params = params[address_type]

        if address_id_param.present?
          address_id = resolve_address_id(address_id_param)
          order.public_send(:"#{address_type}_id=", address_id) if address_id
          return
        end

        return unless address_params.is_a?(Hash)

        if address_params[:id].present?
          address_id = resolve_address_id(address_params[:id])
          order.public_send(:"#{address_type}_id=", address_id) if address_id
        else
          revert_to_address_state if order.has_checkout_step?('address')
          order.public_send(:"#{address_type}_attributes=", address_params)
        end
      end

      def process_line_items
        return unless params[:line_items].is_a?(Array)

        result = Spree.cart_upsert_items_service.call(
          order: order,
          line_items: params[:line_items]
        )

        raise StandardError, result.error.to_s if result.failure?
      end

      def resolve_address_id(prefixed_id)
        return unless order.user

        decoded = Spree::Address.decode_prefixed_id(prefixed_id)
        decoded ? order.user.addresses.find_by(id: decoded)&.id : nil
      end

      def revert_to_address_state
        return if ['cart', 'address'].include?(order.state)

        order.state = 'address'
      end

      # Auto-advance as far as the checkout state machine allows.
      # Loops order.next until the order can't progress further (e.g. missing
      # payment) or reaches confirm/complete. Stops at the first step whose
      # before_transition guard fails — the `requirements` array in the
      # serialized response tells the frontend what's still missing.
      # Failure is swallowed — the update itself already succeeded.
      def try_advance
        return if order.complete? || order.canceled?

        loop do
          break unless order.next
          break if order.confirm? || order.complete?
        end
      rescue StandardError => e
        Rails.error.report(e, context: { order_id: order.id, state: order.state }, source: 'spree.checkout')
      ensure
        begin
          order.reload
        rescue StandardError # rubocop:disable Lint/SuppressedException
          # reload failure must not mask the original result
        end
      end
    end
  end
end
