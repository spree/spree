module SpreeAdyen
  class ConfigureJob < BaseJob
    # Safe to replay: configuration finds what is already in place.
    retry_on StandardError, wait: :polynomially_longer, attempts: 5
    # Must come after `retry_on StandardError` so DeserializationError lands in discard.
    discard_on ActiveJob::DeserializationError

    def perform(payment_method_id)
      # Locked on load: two saves in a row queue two jobs, and both would
      # otherwise create a webhook for the same URL.
      Spree::PaymentMethod.transaction do
        payment_method = Spree::PaymentMethod.lock.find_by(id: payment_method_id)
        next unless payment_method.is_a?(SpreeAdyen::Gateway)

        SpreeAdyen::Configure.call(payment_method)
      end
    end
  end
end
