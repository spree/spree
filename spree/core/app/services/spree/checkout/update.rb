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

        success(order.reload)
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

      # Auto-advance to next checkout step after successful update.
      # Uses order.next (state machine event) directly.
      # Failure is swallowed — the update succeeded, advancement is best-effort.
      # The `requirements` array in the serialized response tells the frontend what's missing.
      def try_advance
        return if order.complete? || order.canceled?

        order.next
      rescue StandardError => e
        Rails.error.report(e, context: { order_id: order.id, state: order.state }, source: 'spree.checkout')
      ensure
        order.reload
      end
    end
  end
end
