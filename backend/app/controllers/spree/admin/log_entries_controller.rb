module Spree
  module Admin
    class LogEntriesController < Spree::Admin::BaseController
      before_action :find_order_and_payment

      def index
        @log_entries = @payment.log_entries
      end

      private

      def find_order_and_payment
        @order = Spree::Order.find_by!(number: params[:order_id])
        @payment = @order.payments.find_by!(number: params[:payment_id])
      end
    end
  end
end
