module Spree
  module Admin
    class PaymentsController < Spree::Admin::BaseController
      before_filter :load_order, :only => [:create, :new, :index, :fire]
      before_filter :load_payment, :except => [:create, :new, :index]
      before_filter :load_data

      respond_to :html

      def index
        @payments = @order.payments
      end

      def new
        @payment = @order.payments.build
      end

      def create
        @payment = @order.payments.build(object_params)
        if @payment.payment_method.is_a?(Spree::Gateway) && @payment.payment_method.payment_profiles_supported? && params[:card].present? and params[:card] != 'new'
          @payment.source = CreditCard.find_by_id(params[:card])
        end

        begin
          unless @payment.save
            redirect_to admin_order_payments_path(@order)
            return
          end

          if @order.completed?
            @payment.process!
            flash[:success] = flash_message_for(@payment, :successfully_created)

             redirect_to admin_order_payments_path(@order)
          else
            #This is the first payment (admin created order)
            until @order.completed?
              @order.next!
            end
            flash[:success] = t(:new_order_completed)
            redirect_to admin_order_url(@order)
          end

        rescue Spree::Core::GatewayError => e
          flash[:error] = "#{e.message}"
          redirect_to new_admin_order_payment_path(@order)
        end
      end

      def fire
        return unless event = params[:e] and @payment.payment_source

        # Because we have a transition method also called void, we do this to avoid conflicts.
        event = "void_transaction" if event == "void"
        if @payment.send("#{event}!")
          flash[:success] = t(:payment_updated)
        else
          flash[:error] = t(:cannot_perform_operation)
        end
      rescue Spree::Core::GatewayError => ge
        flash[:error] = "#{ge.message}"
      ensure
        redirect_to admin_order_payments_path(@order)
      end

      private

      def object_params
        if params[:payment] and params[:payment_source] and source_params = params.delete(:payment_source)[params[:payment][:payment_method_id]]
          params[:payment][:source_attributes] = source_params
        end
        params[:payment]
      end

      def load_data
        @amount = params[:amount] || load_order.total
        @payment_methods = PaymentMethod.available
        if @payment and @payment.payment_method
          @payment_method = @payment.payment_method
        else
          @payment_method = @payment_methods.first
        end
        @previous_cards = @order.credit_cards.with_payment_profile
      end

      def load_order
        @order = Order.find_by_number!(params[:order_id])
      end

      def load_payment
        @payment = Payment.find(params[:id])
      end

    end
  end
end
