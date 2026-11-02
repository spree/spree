module Spree
  module Orders
    # Asks the buyer to pay a draft order the merchant raised. Until then the
    # draft is the merchant's to edit and stays out of the storefront; from
    # here its customer, or whoever holds its order token, can read and pay it.
    #
    # Requesting again re-stamps the request and publishes the event again, so
    # a merchant who re-priced the draft can send the request anew. Telling the
    # customer is left to a subscriber of `order.payment_requested`.
    class RequestPayment < Spree::Workflow
      hooks :validate, :after_request_payment

      # @param order [Spree::Order]
      # @return [Spree::ServiceModule::Result] value is the order
      def perform(order:)
        super

        order.with_lock do
          step :ensure_standalone_draft
          run_hooks :validate

          step :stamp_request
        end

        run_hooks :after_request_payment
        order.publish_event('order.payment_requested')
        success(order.reload)
      end

      private

      # A checkout's own draft is paid through its cart, and one a division
      # left behind is placed by its group.
      def ensure_standalone_draft
        failure(order, I18n.t('spree.order_payment_request_not_draft')) unless order.reload.standalone_draft?
      end

      def stamp_request
        order.update_columns(payment_requested_at: Time.current, updated_at: Time.current)
      end
    end
  end
end
