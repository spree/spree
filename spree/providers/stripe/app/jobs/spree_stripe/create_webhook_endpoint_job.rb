module SpreeStripe
  class CreateWebhookEndpointJob < BaseJob
    # @param connect [Boolean] true registers the connected-accounts endpoint,
    #   which a marketplace holds alongside its payment one
    def perform(payment_method_id, connect: false)
      payment_method = Spree::PaymentMethod.find_by(id: payment_method_id)
      return if payment_method.blank?

      if connect
        payment_method.create_connect_webhook_endpoint
      else
        payment_method.create_webhook_endpoint
      end
    end
  end
end
