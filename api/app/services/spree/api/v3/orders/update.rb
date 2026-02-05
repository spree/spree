module Spree
  module Api
    module V3
      module Orders
        # Clean API v3 order update service with modern conventions:
        # - Flat parameter structure (no wrapping in "order" key)
        # - snake_case field names without "_attributes" suffix
        # - Automatic state management based on what's being updated
        #
        # @example Update shipping address
        #   Spree::Api::V3::Orders::Update.call(
        #     order: order,
        #     params: {
        #       email: "customer@example.com",
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
        # @example Change currency
        #   Spree::Api::V3::Orders::Update.call(
        #     order: order,
        #     params: { currency: "EUR" }
        #   )
        class Update
          prepend Spree::ServiceModule::Base
          include Spree::Addresses::Helper

          PERMITTED_ORDER_PARAMS = %i[
            email
            special_instructions
            currency
            bill_address_id
            ship_address_id
          ].freeze

          def call(order:, params:)
            @order = order
            @params = params.to_h.deep_symbolize_keys

            return failure(order, validation_error) if validation_error.present?

            ApplicationRecord.transaction do
              update_currency if @params[:currency].present?
              update_order_attributes
              update_address(:ship_address)
              update_address(:bill_address)

              order.save!
            end

            success(order.reload)
          rescue ActiveRecord::RecordInvalid => e
            failure(order, e.record.errors.full_messages.to_sentence)
          rescue StandardError => e
            failure(order, e.message)
          end

          private

          attr_reader :order, :params

          def validation_error
            @validation_error ||= begin
              error = validate_address_ownership(:ship_address)
              error ||= validate_address_ownership(:bill_address)
              error
            end
          end

          def validate_address_ownership(address_type)
            # Check nested address params (ship_address: { id: ... })
            address_params = params[address_type]
            if address_params.is_a?(Hash) && address_params[:id].present?
              return ownership_error_for(address_params[:id])
            end

            # Check top-level address ID (ship_address_id: ...)
            address_id = params[:"#{address_type}_id"]
            if address_id.present?
              return ownership_error_for(address_id)
            end

            nil
          end

          def ownership_error_for(address_id)
            address = Spree::Address.find_by_prefix_id(address_id)
            return nil unless address

            # Allow if address has no user (guest address) or belongs to the order's user
            return nil if address.user_id.nil?
            return nil if order.user_id.present? && address.user_id == order.user_id

            Spree.t(:address_not_owned_by_user)
          end

          def update_currency
            new_currency = params[:currency].upcase
            return if order.currency == new_currency

            order.currency = new_currency
            order.homogenize_line_item_currencies
          end

          def update_order_attributes
            order.email = params[:email] if params[:email].present?
            order.special_instructions = params[:special_instructions] if params[:special_instructions].present?
          end

          def update_address(address_type)
            address_id_param = params[:"#{address_type}_id"]
            address_params = params[address_type]

            # Priority 1: Direct address ID reference (ship_address_id / bill_address_id)
            if address_id_param.present?
              assign_existing_address(address_type, address_id_param)
              return
            end

            # Priority 2: Nested address params (ship_address / bill_address)
            return unless address_params.is_a?(Hash)

            if address_params[:id].present?
              # Using existing address by ID within nested params
              assign_existing_address(address_type, address_params[:id])
            else
              # Creating/updating address with provided attributes
              build_address(address_type, address_params)
            end
          end

          def assign_existing_address(address_type, prefix_id)
            existing = Spree::Address.find_by_prefix_id!(prefix_id)
            # Use bracket notation to bypass Order::AddressBook custom setter
            # which requires address.user_id == order.user_id
            order[:"#{address_type}_id"] = existing.id
          end

          def build_address(address_type, address_params)
            normalized = normalize_address_params(address_params)
            revert_to_address_state if order.has_checkout_step?('address')

            existing_address = order.public_send(address_type)
            new_address = build_or_update_address(existing_address, normalized)
            order.public_send(:"#{address_type}=", new_address)
          end

          def normalize_address_params(address_params)
            permitted_keys = Spree::PermittedAttributes.address_attributes.select { |attr| attr.is_a?(Symbol) }
            # Also permit state_abbr which is handled by the helper but not in permitted attributes
            permitted_keys += [:state_abbr]

            normalized = address_params.slice(*permitted_keys)
            fill_country_and_state_ids(normalized)
            normalized
          end

          def build_or_update_address(existing_address, address_params)
            if existing_address.present? && existing_address.editable?
              existing_address.assign_attributes(address_params.except(:id))
              existing_address
            else
              Spree::Address.new(address_params.except(:id).merge(user: order.user))
            end
          end

          # Revert order state to 'address' when address changes
          # This ensures shipments are recreated when transitioning back to delivery
          def revert_to_address_state
            return if order.state == 'cart' || order.state == 'address'

            order.state = 'address'
          end
        end
      end
    end
  end
end
