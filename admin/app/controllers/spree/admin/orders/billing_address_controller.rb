module Spree
  module Admin
    module Orders
      class BillingAddressController < Spree::Admin::BaseController
        include Spree::Admin::OrderConcern

        before_action :load_order

        def new
          @address = @order.build_bill_address
          if @order.user.present?
            @address.first_name = @order.user.first_name
            @address.last_name = @order.user.last_name
            @address.phone = @order.user.phone
          end
        end

        def create
          if params[:billing_address_type] == 'same_as_shipping'
            @order.clone_shipping_address

          elsif params[:billing_address_id].present?
            @address = Spree::Address.accessible_by(current_ability, :manage).find_by_prefix_id!(params[:billing_address_id])
            @order.bill_address_id = @address.id
          else
            @order.bill_address_attributes = address_params
            @address = @order.bill_address
          end

          if @order.save
            if !@order.completed? && @order.line_items.any?
              max_state = if @order.ship_address.present?
                            @order.ensure_updated_shipments
                            'payment'
                          else
                            'address'
                          end

              advance_to_payment_result = Spree.checkout_advance_service.call(order: @order, state: max_state)

              unless advance_to_payment_result.success?
                flash[:error] = advance_to_payment_result.error.value.full_messages.to_sentence
                @order.ensure_updated_shipments
                return redirect_to spree.edit_admin_order_path(@order)
              end
            end

            flash[:success] = Spree.t(:successfully_created, resource: Spree.t(:billing_address))
            redirect_to spree.edit_admin_order_path(@order)
          else
            render :create, status: :unprocessable_entity
          end
        end

        def edit
          @address = @order.bill_address
        end

        def update
          if params[:billing_address_type] == 'same_as_shipping'
            @order.clone_shipping_address
          elsif params[:billing_address_id].present?
            @address = Spree::Address.accessible_by(current_ability, :manage).find_by_prefix_id!(params[:billing_address_id])
            @order.bill_address_id = @address.id
          else
            @order.bill_address_attributes = address_params
            @address = @order.bill_address
          end

          if @order.save
            if !@order.completed? && @order.line_items.any?
              max_state = if @order.ship_address.present?
                            @order.ensure_updated_shipments
                            'payment'
                          else
                            'address'
                          end

              advance_to_payment_result = Spree.checkout_advance_service.call(order: @order, state: max_state)

              unless advance_to_payment_result.success?
                flash[:error] = advance_to_payment_result.error.value.full_messages.to_sentence
                @order.ensure_updated_shipments
                return redirect_to spree.edit_admin_order_path(@order)
              end
            end

            flash[:success] = Spree.t(:successfully_updated, resource: Spree.t(:billing_address))
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
