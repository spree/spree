module Spree
  module Api
    class CheckoutsController < Spree::Api::BaseController
      before_filter :load_order, :only => :update
      before_filter :associate_user, :only => :update

      include Spree::Core::ControllerHelpers::Auth
      include Spree::Core::ControllerHelpers::Order
      include ActionView::Helpers::TranslationHelper

      respond_to :json

      def create
        @order = Order.build_from_api(current_api_user, nested_params)
        next!(:status => 201)
      end

      def update
        if @order.update_attributes(object_params)
          return if after_update_attributes
          state_callback(:after) if @order.next
          respond_with(@order, :default_template => 'spree/api/orders/show')
        else
          respond_with(@order, :default_template => 'spree/api/orders/could_not_transition', :status => 422)
        end
      end

      private

        def object_params
          # For payment step, filter order parameters to produce the expected nested attributes for a single payment and its source, discarding attributes for payment methods other than the one selected
          if @order.payment?
            if params[:payment_source].present? && source_params = params.delete(:payment_source)[params[:order][:payments_attributes].first[:payment_method_id].underscore]
              params[:order][:payments_attributes].first[:source_attributes] = source_params
            end
            if params[:order].present? && params[:order][:payments_attributes]
              params[:order][:payments_attributes].first[:amount] = @order.total
            end
          end
          params[:order]
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
          raise_insufficient_quantity and return if @order.insufficient_stock_lines.present?
          @order.state = params[:state] if params[:state]
          state_callback(:before)
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

        def before_delivery
          return if params[:order].present?
          @order.shipping_method ||= (@order.rate_hash.first && @order.rate_hash.first[:shipping_method])
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
