module SpreeStripe
  class CreateWebhookEndpointJob < BaseJob
    def perform(payment_method_id)
      payment_method = Spree::PaymentMethod.find_by(id: payment_method_id)
      return if payment_method.blank?

      payment_method.create_webhook_endpoint
    end
  end
end
