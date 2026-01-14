module Spree
  module Api
    module V3
      module Storefront
        class OrderAddressesController < BaseController
          include Spree::Api::V3::OrderConcern

          before_action :set_order
          before_action :authorize_order_access!

          # GET /api/v3/storefront/orders/:order_id/billing_address
          # GET /api/v3/storefront/orders/:order_id/shipping_address
          def show
            address = address_type == 'billing' ? @order.bill_address : @order.ship_address

            if address
              render json: serialize_address(address)
            else
              render json: { error: 'Address not found' }, status: :not_found
            end
          end

          # PATCH /api/v3/storefront/orders/:order_id/billing_address
          # PATCH /api/v3/storefront/orders/:order_id/shipping_address
          def update
            address = address_type == 'billing' ? @order.bill_address : @order.ship_address

            if address.nil?
              # Create new address
              address = Spree::Address.new(address_params)
              if address_type == 'billing'
                @order.bill_address = address
              else
                @order.ship_address = address
              end
            else
              # Update existing address
              address.assign_attributes(address_params)
            end

            if @order.save
              render json: serialize_address(address)
            else
              render_errors(address.errors.any? ? address.errors : @order.errors)
            end
          end

          protected

          def address_type
            params[:address_type]
          end

          def serialize_address(address)
            serializer_class.new(address, params: serializer_params).to_h
          end

          def serializer_class
            Spree.api.v3_storefront_address_serializer
          end

          def serializer_params
            {
              store: current_store,
              locale: current_locale,
              includes: include_tree
            }
          end

          def address_params
            params.require(:address).permit(Spree::PermittedAttributes.address_attributes)
          end
        end
      end
    end
  end
end
