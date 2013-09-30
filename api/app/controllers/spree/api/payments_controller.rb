module Spree
  module Api
    class PaymentsController < Spree::Api::BaseController
      respond_to :json

      before_filter :find_order
      before_filter :find_payment, only: [:update, :show, :authorize, :purchase, :capture, :void, :credit]

      def index
        @payments = @order.payments.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
        respond_with(@payments)
      end

      def new
        @payment_methods = Spree::PaymentMethod.where(:environment => Rails.env)
        respond_with(@payment_method)
      end

      def create
        @payment = @order.payments.build(params[:payment])
        if @payment.save
          respond_with(@payment, :status => 201, :default_template => :show)
        else
          invalid_resource!(@payment)
        end
      end

      def update
        authorize! params[:action], @payment
        if !@payment.pending?
          render 'update_forbidden', status: 403
        elsif @payment.update_attributes(params[:payment])
          respond_with(@payment, default_template: :show)
        else
          invalid_resource!(@payment)
        end
      end

      def show
        respond_with(@payment)
      end

      def authorize
        perform_payment_action(:authorize)
      end

      def capture
        perform_payment_action(:capture)
      end

      def purchase
        perform_payment_action(:purchase)
      end

      def void
        perform_payment_action(:void_transaction)
      end

      def credit
        if params[:amount].to_f > @payment.credit_allowed
          render 'credit_over_limit', status: 422
        else
          perform_payment_action(:credit, params[:amount])
        end
      end

      private

      def find_order
        @order = Order.find_by_number(params[:order_id])
        authorize! :read, @order
      end

      def find_payment
        @payment = @order.payments.find(params[:id])
      end

      def perform_payment_action(action, *args)
        authorize! action, Payment

        begin
          @payment.send("#{action}!", *args)
          respond_with(@payment, :default_template => :show)
        rescue Spree::Core::GatewayError => e
          @error = e.message
          render "spree/api/errors/gateway_error", :status => 422
        end
      end
    end
  end
end
