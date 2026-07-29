module Spree
  module Checkout
    class Update
      prepend Spree::ServiceModule::Base
      include Spree::Addresses::Helper

      def call(order:, params:, permitted_attributes:, request_env:)
        # Validate address ownership to prevent IDOR attacks
        address_ownership_error = validate_address_ownership(order, params)
        return failure(order, address_ownership_error) if address_ownership_error

        ship_changed = address_with_country_iso_present?(params, 'ship')
        bill_changed = address_with_country_iso_present?(params, 'bill')
        params[:order][:ship_address_attributes] = replace_country_iso_with_id(params[:order][:ship_address_attributes]) if ship_changed
        params[:order][:bill_address_attributes] = replace_country_iso_with_id(params[:order][:bill_address_attributes]) if bill_changed

        # An address change invalidates the delivery proposals — rebuild them
        # (recalculation-on-write; there are no states to rewind).
        address_changed = ship_changed || bill_changed || quick_checkout_cancelled?(params)

        return success(order) if update_from_params(order, params, permitted_attributes, request_env, address_changed)

        failure(order)
      end

      private

      def update_from_params(order, params, permitted_attributes, request_env, address_changed)
        massage_payment_params!(order, params)

        attributes = params[:order] ? params[:order].permit(permitted_attributes).delete_if { |_k, v| v.nil? } : {}

        if (existing_card_id = params[:order]&.delete(:existing_card)).present?
          credit_card = Spree::CreditCard.find(existing_card_id)
          if credit_card.user_id != order.user_id || credit_card.user_id.blank?
            raise Spree::Core::GatewayError, Spree.t(:invalid_credit_card)
          end

          credit_card.verification_value = params[:cvc_confirm] if params[:cvc_confirm].present?

          attributes[:payments_attributes].first[:source] = credit_card
          attributes[:payments_attributes].first[:payment_method_id] = credit_card.payment_method_id
          attributes[:payments_attributes].first.delete(:source_attributes)
        end

        attributes[:payments_attributes].first[:request_env] = request_env if attributes[:payments_attributes]

        result = order.update(attributes)
        if result
          order.recalculate_for_address_change! if address_changed && order.respond_to?(:recalculate_for_address_change!)
          order.set_shipments_cost if order.respond_to?(:set_shipments_cost) && order.fulfillments.any?
        end
        result
      end

      # For the payment step, filter parameters to the nested attributes of
      # the selected payment method and set the chargeable amount.
      def massage_payment_params!(order, params)
        if params[:payment_source].present? && params.dig(:order, :payments_attributes)
          source_params = params.delete(:payment_source)[params[:order][:payments_attributes].first[:payment_method_id].to_s]
          params[:order][:payments_attributes].first[:source_attributes] = source_params if source_params
        end

        if params[:order] && (params[:order][:payments_attributes] || params[:order][:existing_card])
          params[:order][:payments_attributes] ||= [{}]
          params[:order][:payments_attributes].first[:amount] = order.order_total_after_store_credit
        end
      end

      def validate_address_ownership(order, params)
        return nil unless params[:order]

        %w[bill ship].each do |address_kind|
          address_id = params[:order].dig("#{address_kind}_address_attributes".to_sym, :id)
          next unless address_id

          address = Spree::Address.find_by(id: address_id)
          next unless address

          # Allow if address has no user (guest address) or belongs to the order's user
          next if address.user_id.nil?
          next if order.user_id.present? && address.user_id == order.user_id

          return Spree.t(:address_not_owned_by_user)
        end

        nil
      end

      def address_with_country_iso_present?(params, address_kind = 'ship')
        return false unless params.dig(:order, "#{address_kind}_address_attributes".to_sym, :country_iso)
        return false if params.dig(:order, "#{address_kind}_address_attributes".to_sym, :country_id)

        true
      end

      def selected_shipping_rate_present?(params)
        shipments_attributes = params.dig(:order, :shipments_attributes)
        return false unless shipments_attributes

        shipments_attributes.any? { |s| s.dig(:selected_shipping_rate_id) }
      end

      def quick_checkout_cancelled?(params)
        params.dig(:order, :ship_address_id) == 'CLEAR'
      end
    end
  end
end
