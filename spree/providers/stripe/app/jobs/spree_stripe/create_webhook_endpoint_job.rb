module SpreeStripe
  class CreateWebhookEndpointJob < BaseJob
    # @param connect [Boolean] true registers the connected-accounts endpoint,
    #   which a marketplace holds alongside its payment one
    def perform(payment_method_id, connect: false)
      # Both endpoints store their credentials in the one serialised
      # `preferences` column, so concurrent jobs would drop each other's
      # signing secret. Locked on load because `with_lock` refuses a record
      # with unsaved changes, and reading a preference populates its default.
      Spree::PaymentMethod.transaction do
        payment_method = Spree::PaymentMethod.lock.find_by(id: payment_method_id)
        next if payment_method.blank?

        if connect
          payment_method.create_connect_webhook_endpoint
        else
          payment_method.create_webhook_endpoint
        end
      end
    end
  end
end
