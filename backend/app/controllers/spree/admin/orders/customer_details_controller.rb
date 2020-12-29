module Spree
  module Admin
    module Orders
      class CustomerDetailsController < Spree::Admin::BaseController
        before_action :load_order
        before_action :load_user, only: :update, unless: :guest_checkout?

        def show
          edit
          render action: :edit
        end

        def edit
          country_id = Address.default.country.id
          @order.build_bill_address(country_id: country_id) if @order.bill_address.nil?
          @order.build_ship_address(country_id: country_id) if @order.ship_address.nil?

          @order.bill_address.country_id = country_id if @order.bill_address.country.nil?
          @order.ship_address.country_id = country_id if @order.ship_address.country.nil?
        end

        def update
          if @order.update(order_params)
            @order.associate_user!(@user, @order.email.blank?) unless guest_checkout?
            @order.next if @order.address?
            @order.refresh_shipment_rates(Spree::ShippingMethod::DISPLAY_ON_BACK_END)

            if @order.errors.empty?
              flash[:success] = Spree.t('customer_details_updated')
              redirect_to edit_admin_order_url(@order)
            else
              render action: :edit
            end
          else
            render action: :edit
          end
        end

        private

        def order_params
          params.require(:order).permit(
            :email, :user_id, :use_billing,
            bill_address_attributes: permitted_address_attributes,
            ship_address_attributes: permitted_address_attributes
          )
        end

        def load_order
          @order = Order.includes(:adjustments).find_by!(number: params[:order_id])
        end

        def model_class
          Spree::Order
        end

        def load_user
          @user = (Spree.user_class.find_by(id: order_params[:user_id]) ||
            Spree.user_class.find_by(email: order_params[:email]))

          unless @user
            flash.now[:error] = Spree.t(:user_not_found)
            render :edit
          end
        end

        def guest_checkout?
          params[:guest_checkout] == 'true'
        end
      end
    end
  end
end
