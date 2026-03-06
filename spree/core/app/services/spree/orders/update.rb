module Spree
  module Orders
    # Core order update service with modern conventions:
    # - Flat parameter structure (no wrapping in "order" key)
    # - snake_case field names without "_attributes" suffix
    # - Automatic state management based on what's being updated
    # - Support for line_items with prefixed variant IDs
    #
    # @example Update order with line items
    #   Spree::Orders::Update.call(
    #     order: order,
    #     params: {
    #       email: "customer@example.com",
    #       line_items: [
    #         { variant_id: "variant_123", quantity: 2 },
    #         { variant_id: "variant_456", quantity: 1 }
    #       ],
    #       ship_address: {
    #         firstname: "John",
    #         lastname: "Doe",
    #         address1: "123 Main St",
    #         city: "New York",
    #         zipcode: "10001",
    #         country_iso: "US",
    #         state_abbr: "NY"
    #       }
    #     }
    #   )
    #
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

        # Priority 1: Direct address ID reference (ship_address_id / bill_address_id)
        if address_id_param.present?
          address_id = resolve_address_id(address_id_param)
          order.public_send(:"#{address_type}_id=", address_id) if address_id
          return
        end

        # Priority 2: Nested address params (ship_address / bill_address)
        return unless address_params.is_a?(Hash)

        if address_params[:id].present?
          # Using existing address by ID within nested params
          address_id = resolve_address_id(address_params[:id])
          order.public_send(:"#{address_type}_id=", address_id) if address_id
        else
          # Creating/updating address with provided attributes
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

      # Translate prefixed ID to internal id
      def resolve_address_id(prefixed_id)
        return unless order.user

        decoded = Spree::Address.decode_prefixed_id(prefixed_id)
        decoded ? order.user.addresses.find_by(id: decoded)&.id : nil
      end

      # Revert order state to 'address' when address changes
      # This ensures shipments are recreated when transitioning back to delivery
      def revert_to_address_state
        return if ['cart', 'address'].include?(order.state)

        order.state = 'address'
      end
    end
  end
end
