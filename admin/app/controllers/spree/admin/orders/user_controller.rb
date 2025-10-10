module Spree
  module Admin
    module Orders
      class UserController < Spree::Admin::BaseController
        include Spree::Admin::OrderConcern
        before_action :load_order
        before_action :check_authorization

        def new
          @user = @order.build_user
        end

        def create
          @user = Spree.user_class.find_by(email: params.dig(:user, :email))

          if @user
            @order.associate_user!(@user)
            if @user.update(user_params) && @order.line_items.any?
              max_state = if @order.ship_address.present?
                            @order.ensure_updated_shipments
                            'payment'
                          else
                            'address'
                          end

              result = Spree::Dependencies.checkout_advance_service.constantize.call(order: @order, state: max_state)

              flash[:error] = result.error.value.full_messages.to_sentence unless result.success?

              render :create, status: :ok
            else
              render :create, status: :unprocessable_entity
            end
          else
            @user = @order.build_user(user_params)
            @user.password ||= SecureRandom.hex(16) # we need to set a password to pass validation
            @user.password_confirmation ||= @user.password

            if @user.save
              @order.associate_user!(@user)

              render :create, status: :ok
            else
              render :create, status: :unprocessable_entity
            end
          end
        end

        def update
          user = Spree.user_class.find(params[:user_id])
          @order.associate_user!(user)

          if !@order.completed? && @order.line_items.any?
            max_state = if @order.ship_address.present?
                          @order.ensure_updated_shipments
                          'payment'
                        else
                          'address'
                        end

            result = Spree::Dependencies.checkout_advance_service.constantize.call(order: @order, state: max_state)

            unless result.success?
              flash[:error] = result.error.value.full_messages.to_sentence
              @order.ensure_updated_shipments
            end
          end

          render :update, status: :ok
        end

        def destroy
          @order.assign_attributes(user_id: nil, ship_address: nil, bill_address: nil)
          @order.email = nil unless @order.email_required?
          @order.save

          flash[:error] = @order.errors.full_messages.to_sentence if @order.invalid?

          redirect_to spree.edit_admin_order_path(@order)
        end

        private

        def user_params
          params.require(:user).permit(permitted_user_attributes)
        end

        def check_authorization
          authorize! :update_customer, @order
        end
      end
    end
  end
end
