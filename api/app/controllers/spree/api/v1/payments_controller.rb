module Spree
  module Api
    module V1
      class PaymentsController < Spree::Api::V1::BaseController
        before_filter :find_order
        before_filter :find_payment, :only => [:show, :authorize, :capture]

        def index
          @payments = @order.payments
        end

        def new
          @payment_methods = Spree::PaymentMethod.where(:environment => Rails.env)
        end

        def create
          @payment = @order.payments.build(params[:payment])
          if @payment.save
            render :show, :status => 201
          else
            invalid_resource!(@payment)
          end
        end

        def show
        end

        def authorize
          authorize! :authorize, Payment
          begin
            @payment.authorize!
          rescue Spree::Core::GatewayError
            #noop, will deal with it in the response
          end

          if @payment.failed?
            render :gateway_error, :status => 422
          else
            render :show, :status => 200
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
      end
    end
  end
end
