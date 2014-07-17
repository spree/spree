module Spree
  module Admin
    class RefundsController < ResourceController
      belongs_to 'spree/payment'
      before_filter :load_order

      helper_method :refund_reasons

      private

      def location_after_save
        admin_order_payments_path(@payment.order)
      end

      def load_order
        # the spree/admin/shared/order_tabs partial expects the @order instance variable to be set
        @order = @payment.order if @payment
      end

      def refund_reasons
        @refund_reasons ||= RefundReason.active.all
      end

      def build_resource
        super.tap do |refund|
          refund.amount = refund.payment.credit_allowed
        end
      end
    end
  end
end
