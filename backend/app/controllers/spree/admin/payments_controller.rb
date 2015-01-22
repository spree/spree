module Spree
  module Admin
    class PaymentsController < Spree::Admin::BaseController
      include Spree::Backend::Callbacks

      before_action :load_order, only: [:create, :new, :index, :fire]
      before_action :load_payment, except: [:create, :new, :index]
      before_action :load_data
      before_action :can_not_transition_without_customer_info

      respond_to :html

      def index
        @payments = @order.payments.includes(:refunds => :reason)
        @refunds = @payments.flat_map(&:refunds)
        redirect_to new_admin_order_payment_url(@order) if @payments.empty?
      end

      def new
        @payment = @order.payments.build
      end

      def create
        invoke_callbacks(:create, :before)
        @payment ||= @order.payments.build(object_params)
        if @payment.payment_method.source_required? && params[:card].present? and params[:card] != 'new'
          @payment.source = @payment.payment_method.payment_source_class.find_by_id(params[:card])
        end

        begin
          if @payment.save
            invoke_callbacks(:create, :after)
            # Transition order as far as it will go.
            while @order.next; end
            # If "@order.next" didn't trigger payment processing already (e.g. if the order was
            # already complete) then trigger it manually now
            @payment.process! if @order.completed? && @payment.checkout?
            flash[:success] = flash_message_for(@payment, :successfully_created)
            redirect_to admin_order_payments_path(@order)
          else
            invoke_callbacks(:create, :fails)
            flash[:error] = Spree.t(:payment_could_not_be_created)
            render :new
          end
        rescue Spree::Core::GatewayError => e
          invoke_callbacks(:create, :fails)
          flash[:error] = "#{e.message}"
          redirect_to new_admin_order_payment_path(@order)
        end
      end

      def fire
        return unless event = params[:e] and @payment.payment_source

        # Because we have a transition method also called void, we do this to avoid conflicts.
        event = "void_transaction" if event == "void"
        if @payment.send("#{event}!")
          flash[:success] = Spree.t(:payment_updated)
        else
          flash[:error] = Spree.t(:cannot_perform_operation)
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

        params.require(:payment).permit(permitted_payment_attributes)
      end

      def load_data
        @amount = params[:amount] || load_order.total
        @payment_methods = PaymentMethod.available(:back_end)
        if @payment and @payment.payment_method
          @payment_method = @payment.payment_method
        else
          @payment_method = @payment_methods.first
        end
      end

      def load_order
        @order = Order.friendly.find(params[:order_id])
        authorize! action, @order
        @order
      end

      def load_payment
        @payment = Payment.friendly.find(params[:id])
      end

      def model_class
        Spree::Payment
      end
    end
  end
end
