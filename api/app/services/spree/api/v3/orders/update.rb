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

          PERMITTED_ADDRESS_PARAMS = %i[
            id
            firstname
            lastname
            address1
            address2
            city
            zipcode
            phone
            company
            country_iso
            state_abbr
            state_name
          ].freeze

          def call(order:, params:)
            @order = order
            @params = params.to_h.deep_symbolize_keys

            return failure(order, validation_error) if validation_error.present?

            ApplicationRecord.transaction do
              update_currency if @params[:currency].present?
              update_email if @params[:email].present?
              update_special_instructions if @params[:special_instructions].present?
              update_ship_address if @params[:ship_address].present?
              update_bill_address if @params[:bill_address].present?
              update_address_ids

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
              error = validate_currency
              error ||= validate_address_ownership(:ship_address)
              error ||= validate_address_ownership(:bill_address)
              error
            end
          end

          def validate_currency
            new_currency = params[:currency]
            return nil unless new_currency.present?

            supported_currencies = order.store.supported_currencies_list.map(&:iso_code)
            return nil if supported_currencies.include?(new_currency.upcase)

            Spree.t(:currency_not_supported, currency: new_currency)
          end

          def validate_address_ownership(address_type)
            address_params = params[address_type]
            return nil unless address_params.is_a?(Hash)

            address_id = address_params[:id]
            return nil unless address_id.present?

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

          def update_email
            order.email = params[:email]
          end

          def update_special_instructions
            order.special_instructions = params[:special_instructions]
          end

          def update_ship_address
            address_params = normalize_address_params(params[:ship_address])

            if address_params[:id].present?
              # Using existing address - find by prefix_id
              existing = Spree::Address.find_by_prefix_id!(address_params[:id])
              order.ship_address_id = existing.id
            else
              # Creating/updating address
              revert_to_address_state if order.has_checkout_step?('address')
              order.ship_address = build_or_update_address(order.ship_address, address_params)
            end
          end

          def update_bill_address
            address_params = normalize_address_params(params[:bill_address])

            if address_params[:id].present?
              # Using existing address - find by prefix_id
              existing = Spree::Address.find_by_prefix_id!(address_params[:id])
              order.bill_address_id = existing.id
            else
              # Creating/updating address
              revert_to_address_state if order.has_checkout_step?('address')
              order.bill_address = build_or_update_address(order.bill_address, address_params)
            end
          end

          def update_address_ids
            if params[:ship_address_id].present?
              existing = Spree::Address.find_by_prefix_id!(params[:ship_address_id])
              # Use bracket notation to bypass Order::AddressBook custom setter
              # which requires address.user_id == order.user_id
              order[:ship_address_id] = existing.id
            end
            if params[:bill_address_id].present?
              existing = Spree::Address.find_by_prefix_id!(params[:bill_address_id])
              # Use bracket notation to bypass Order::AddressBook custom setter
              order[:bill_address_id] = existing.id
            end
          end

          def normalize_address_params(address_params)
            return {} unless address_params.is_a?(Hash)

            normalized = address_params.slice(*PERMITTED_ADDRESS_PARAMS)
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
