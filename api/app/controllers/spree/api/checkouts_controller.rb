module Spree
  module Api
    class CheckoutsController < Spree::Api::BaseController

      before_filter :load_order,     only: [:show, :update, :next, :advance]
      before_filter :associate_user, only: :update

      include Spree::Core::ControllerHelpers::Auth
      include Spree::Core::ControllerHelpers::Order
      # This before_filter comes from Spree::Core::ControllerHelpers::Order
      skip_before_filter :set_current_order

      respond_to :json

      def create
        @order = Order.build_from_api(current_api_user, nested_params)
        respond_with(@order, default_template: 'spree/api/orders/show', status: 201)
      end

      def next
        authorize! :update, @order, params[:order_token]
        @order.next!
        respond_with(@order, default_template: 'spree/api/orders/show', status: 200)
      rescue StateMachine::InvalidTransition
        respond_with(@order, default_template: 'spree/api/orders/could_not_transition', status: 422)
      end

      def advance
        authorize! :update, @order, params[:order_token]
        while @order.next; end
        respond_with(@order, default_template: 'spree/api/orders/show', status: 200)
      end

      def show
        respond_with(@order, default_template: 'spree/api/orders/show', status: 200)
      end

      def update
        authorize! :update, @order, params[:order_token]
        order_params = object_params
        user_id = order_params.delete(:user_id)
        line_items = order_params.delete("line_items_attributes")
        if @order.update_attributes(order_params)
          @order.update_line_items(line_items)
          if current_api_user.has_spree_role?("admin") && user_id.present?
            @order.associate_user!(Spree.user_class.find(user_id))
          end
          return if after_update_attributes
          state_callback(:after) if @order.next
          respond_with(@order, :default_template => 'spree/api/orders/show')
        else
          invalid_resource!(@order)
        end
      end

      def next
        @order.next!
        authorize! :update, @order, params[:order_token]
        respond_with(@order, :default_template => 'spree/api/orders/show', :status => 200)
        rescue StateMachine::InvalidTransition
          respond_with(@order, :default_template => 'spree/api/orders/could_not_transition', :status => 422)
      end

      private

        def object_params
          # For payment step, filter order parameters to produce the expected nested attributes for a single payment and its source, discarding attributes for payment methods other than the one selected
          # respond_to check is necessary due to issue described in #2910
          object_params = nested_params
          if @order.has_checkout_step?("payment") && @order.payment?
            if object_params[:payment_source].present? && source_params = object_params.delete(:payment_source)[object_params[:payments_attributes].first[:payment_method_id].underscore]
              object_params[:payments_attributes].first[:source_attributes] = source_params
            end
            if object_params.present? && object_params[:payments_attributes]
              object_params[:payments_attributes].first[:amount] = @order.total
            end
          end
          object_params
        end

        def nested_params
          map_nested_attributes_keys Order, params[:order] || {}
        end

        # Should be overriden if you have areas of your checkout that don't match
        # up to a step within checkout_steps, such as a registration step
        def skip_state_validation?
          false
        end

        def load_order
          @order = Spree::Order.find_by_number!(params[:id])
          authorize! :read, @order, params[:order_token]
          raise_insufficient_quantity and return if @order.insufficient_stock_lines.present?
          @order.state = params[:state] if params[:state]
          state_callback(:before)
        end

        def current_currency
          Spree::Config[:currency]
        end

        def ip_address
          ''
        end

        def raise_insufficient_quantity
          respond_with(@order, :default_template => 'spree/api/orders/insufficient_quantity')
        end

        def state_callback(before_or_after = :before)
          method_name = :"#{before_or_after}_#{@order.state}"
          send(method_name) if respond_to?(method_name, true)
        end

        def before_address
          @order.bill_address ||= Address.default
          @order.ship_address ||= Address.default
        end

        def before_payment
          @order.payments.destroy_all if request.put?
        end

        def next!(options={})
          if @order.valid? && @order.next
            render 'spree/api/orders/show', :status => options[:status] || 200
          else
            render 'spree/api/orders/could_not_transition', :status => 422
          end
        end

        def after_update_attributes
          if object_params && object_params[:coupon_code].present?
            coupon_result = Spree::Promo::CouponApplicator.new(@order).apply
            if !coupon_result[:coupon_applied?]
              @coupon_message = coupon_result[:error]
              respond_with(@order, :default_template => 'spree/api/orders/could_not_apply_coupon')
              return true
            end
          end
          false
        end
    end
  end
end
