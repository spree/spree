module Spree
  module Admin
    module Orders
      class CustomerDetailsController < Spree::Admin::BaseController
        before_action :load_order

        def show
          edit
          render :action => :edit
        end

        def edit
          bill_address = @order.bill_address ||= Address.default
          ship_address = @order.ship_address ||= Address.default

          country = Address.default.country
          bill_address.country ||= country
          ship_address.country ||= country
        end

        def update
          if @order.update_attributes(order_params)
            if params[:guest_checkout] == "false"
              @order.associate_user!(Spree.user_class.find(params[:user_id]), @order.email.blank?)
            end
            @order.advance
            @order.refresh_shipment_rates
            flash[:success] = Spree.t('customer_details_updated')
            redirect_to edit_admin_order_url(@order)
          else
            render :action => :edit
          end

        end

        private
          def order_params
            params.require(:order).permit(
              :email,
              :use_billing,
              :bill_address_attributes => permitted_address_attributes,
              :ship_address_attributes => permitted_address_attributes
            )
          end

          def load_order
            @order = Order.includes(:all_adjustments).find_by_number!(params.fetch(:order_id))
          end

          def model_class
            Spree::Order
          end

      end
    end
  end
end
