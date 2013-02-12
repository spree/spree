module Spree
  # This is somewhat contrary to standard REST convention since there is not
  # actually a Checkout object. There's enough distinct logic specific to
  # checkout which has nothing to do with updating an order that this approach
  # is waranted.
  class CheckoutController < Spree::StoreController
    ssl_required

    before_filter :load_order

    before_filter :ensure_order_not_completed
    before_filter :ensure_checkout_allowed
    before_filter :ensure_sufficient_stock_lines
    before_filter :ensure_valid_state

    before_filter :associate_user
    before_filter :check_authorization

    rescue_from Spree::Core::GatewayError, :with => :rescue_from_spree_gateway_error

    helper 'spree/orders'

    # Updates the order and advances to the next state (when possible.)
    # Overriden by the promo gem if it exists. 
    def update
      if @order.update_attributes(object_params)
        fire_event('spree.checkout.update')
        unless apply_coupon_code
          respond_with(@order) { |format| format.html { render :edit } }
          return
        end

        unless @order.next
          flash[:error] = t(:payment_processing_failed)
          redirect_to checkout_state_path(@order.state) and return
        end

        if @order.state == "complete" || @order.completed?
          session[:order_id] = nil
          flash.notice = t(:order_processed_successfully)
          flash[:commerce_tracking] = "nothing special"
          redirect_to completion_route
        else
          redirect_to checkout_state_path(@order.state)
        end
      else
        render :edit
      end
    end

    private
      def ensure_valid_state
        unless skip_state_validation?
          if (params[:state] && !@order.checkout_steps.include?(params[:state])) ||
             (!params[:state] && !@order.checkout_steps.include?(@order.state))
            @order.state = 'cart'
            redirect_to checkout_state_path(@order.checkout_steps.first)
          end
        end
      end

      # Should be overriden if you have areas of your checkout that don't match
      # up to a step within checkout_steps, such as a registration step
      def skip_state_validation?
        false
      end

      def load_order
        @order = current_order
        redirect_to spree.cart_path and return unless @order

        @order.state = params[:state] if params[:state]
        setup_for_current_state
      end

      def ensure_checkout_allowed
        unless @order.checkout_allowed?
          redirect_to spree.cart_path
        end
      end

      def ensure_order_not_completed
        redirect_to spree.cart_path if @order.completed?
      end

      def ensure_sufficient_stock_lines
        if @order.insufficient_stock_lines.present?
          flash[:error] = t(:spree_inventory_error_flash_for_insufficient_quantity)
          redirect_to spree.cart_path
        end
      end

      # Provides a route to redirect after order completion
      def completion_route
        spree.order_path(@order)
      end

      # For payment step, filter order parameters to produce the expected nested
      # attributes for a single payment and its source, discarding attributes
      # for payment methods other than the one selected
      def object_params
        if @order.payment?
          if params[:payment_source].present?
            source_params = params.delete(:payment_source)[params[:order][:payments_attributes].first[:payment_method_id].underscore]

            if source_params
              params[:order][:payments_attributes].first[:source_attributes] = source_params
            end
          end

          if (params[:order][:payments_attributes])
            params[:order][:payments_attributes].first[:amount] = @order.total
          end
        end
        params[:order]
      end

      def setup_for_current_state
        method_name = :"before_#{@order.state}"
        send(method_name) if respond_to?(method_name, true)
      end

      def before_address
        @order.bill_address ||= Address.default
        @order.ship_address ||= Address.default
      end

      def before_delivery
        return if params[:order].present?
        @order.shipping_method ||= (@order.rate_hash.first && @order.rate_hash.first[:shipping_method])
      end

      def rescue_from_spree_gateway_error
        flash[:error] = t(:spree_gateway_error_flash_for_checkout)
        render :edit
      end

      def check_authorization
        authorize!(:edit, current_order, session[:access_token])
      end
  end
end
