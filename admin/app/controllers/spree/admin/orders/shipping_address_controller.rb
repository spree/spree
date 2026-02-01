module Spree
  module Admin
    module Orders
      class ShippingAddressController < Spree::Admin::BaseController
        include Spree::Admin::OrderConcern

        before_action :load_order

        def new
          @address = @order.build_ship_address
          if @order.user.present?
            @address.first_name = @order.user.first_name
            @address.last_name = @order.user.last_name
            @address.phone = @order.user.phone
          end
        end

        def create
          @order.ship_address_attributes = address_params
          @address = @order.ship_address

          if @order.save
            @order.shipments.update_all(address_id: @order.ship_address.id, updated_at: Time.current)
            if !@order.completed? && @order.line_items.any?
              @order.ensure_updated_shipments
              advance_to_payment_result = Spree.checkout_advance_service.call(order: @order, state: 'payment')

              unless advance_to_payment_result.success?
                flash[:error] = advance_to_payment_result.error.value.full_messages.to_sentence
                @order.ensure_updated_shipments
                return redirect_to spree.edit_admin_order_path(@order)
              end
            end

            flash[:success] = Spree.t(:successfully_created, resource: Spree.t(:shipping_address))

            redirect_to spree.edit_admin_order_path(@order)
          else
            render :create, status: :unprocessable_entity
          end
        end

        def edit
          @address = @order.ship_address
        end

        def update
          if params[:shipping_address_id].present?
            @address = Spree::Address.accessible_by(current_ability, :manage).find_by_prefix_id!(params[:shipping_address_id])
            @order.ship_address_id = @address.id
          else
            @order.ship_address_attributes = address_params
            @address = @order.ship_address
          end

          if @order.save
            @order.shipments.update_all(address_id: @order.ship_address.id, updated_at: Time.current)
            if !@order.completed? && @order.line_items.any?
              @order.ensure_updated_shipments
              advance_to_payment_result = Spree.checkout_advance_service.call(order: @order, state: 'payment')

              unless advance_to_payment_result.success?
                flash[:error] = advance_to_payment_result.error.value.full_messages.to_sentence
                @order.ensure_updated_shipments
                return redirect_to spree.edit_admin_order_path(@order)
              end
            end

            flash[:success] = Spree.t(:successfully_updated, resource: Spree.t(:shipping_address))

            redirect_to spree.edit_admin_order_path(@order)
          else
            render :update, status: :unprocessable_entity
          end
        end

        private

        def address_params
          params.require(:address).permit(permitted_address_attributes)
        end
      end
    end
  end
end
