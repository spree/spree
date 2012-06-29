module Spree
  # Handles checkout logic.  This is somewhat contrary to standard REST convention since there is not actually a
  # Checkout object.  There's enough distinct logic specific to checkout which has nothing to do with updating an
  # order that this approach is waranted.
  class CheckoutController < BaseController
    ssl_required

    before_filter :load_order
    before_filter :associate_user
    rescue_from Spree::Core::GatewayError, :with => :rescue_from_spree_gateway_error

    respond_to :html

    # Updates the order and advances to the next state (when possible.)
    def update
      if @order.update_attributes(object_params)
        fire_event('spree.checkout.update')

        if @order.next
          state_callback(:after)
        else
          flash[:error] = t(:payment_processing_failed)
          respond_with(@order, :location => checkout_state_path(@order.state))
          return
        end

        if @order.state == "complete" || @order.completed?
          flash.notice = t(:order_processed_successfully)
          flash[:commerce_tracking] = "nothing special"
          respond_with(@order, :location => completion_route)
        else
          respond_with(@order, :location => checkout_state_path(@order.state))
        end
      else
        respond_with(@order) { |format| format.html { render :edit } }
      end
    end

    private
      def load_order
        @order = current_order
        redirect_to cart_path and return unless @order and @order.checkout_allowed?
        raise_insufficient_quantity and return if @order.insufficient_stock_lines.present?
        redirect_to cart_path and return if @order.completed?
        @order.state = params[:state] if params[:state]
        state_callback(:before)
      end

      def associate_user
        if try_spree_current_user && @order
          if @order.user.blank? || @order.email.blank?
            @order.associate_user!(try_spree_current_user)
          end
        end

        # This will trigger any "first order" promotions to be triggered
        # Assuming of course that this session variable was set correctly in
        # the authentication provider's registrations controller
        if session[:spree_user_signup]
          fire_event('spree.user.signup', :user => try_spree_current_user, :order => current_order(true))
        end

        session[:guest_token] = nil
        session[:spree_user_signup] = nil
      end

      # Provides a route to redirect after order completion
      def completion_route
        order_path(@order)
      end

      def object_params
        # For payment step, filter order parameters to produce the expected nested attributes for a single payment and its source, discarding attributes for payment methods other than the one selected
        if @order.payment?
          if params[:payment_source].present? && source_params = params.delete(:payment_source)[params[:order][:payments_attributes].first[:payment_method_id].underscore]
            params[:order][:payments_attributes].first[:source_attributes] = source_params
          end
          if (params[:order][:payments_attributes])
            params[:order][:payments_attributes].first[:amount] = @order.total
          end
        end
        params[:order]
      end

      def raise_insufficient_quantity
        flash[:error] = t(:spree_inventory_error_flash_for_insufficient_quantity)
        redirect_to cart_path
      end

      def state_callback(before_or_after = :before)
        method_name = :"#{before_or_after}_#{@order.state}"
        send(method_name) if respond_to?(method_name, true)
      end

      def before_address
        @order.bill_address ||= Address.default
        if @order.delivery_required?
          @order.ship_address ||= Address.default
        end
      end

      def before_delivery
        return if params[:order].present?
        @order.shipping_method ||= (@order.rate_hash.first && @order.rate_hash.first[:shipping_method])
      end

      def before_payment
        current_order.payments.destroy_all if request.put?
      end

      def after_complete
        session[:order_id] = nil
      end

      def rescue_from_spree_gateway_error
        flash[:error] = t(:spree_gateway_error_flash_for_checkout)
        render :edit
      end
  end
end
