module Spree
  class PaymentSessions::Stripe < PaymentSession
    delegate :api_options, to: :payment_method

    def stripe_id
      external_id
    end

    def client_secret
      external_data&.dig('client_secret')
    end

    def ephemeral_key_secret
      external_data&.dig('ephemeral_key_secret')
    end

    def stripe_payment_intent
      @stripe_payment_intent ||= payment_method.retrieve_payment_intent(external_id)
    end

    def stripe_charge
      @stripe_charge ||= begin
        latest_charge = stripe_payment_intent.latest_charge
        latest_charge.present? ? payment_method.retrieve_charge(latest_charge) : nil
      end
    end

    def accepted?
      payment_method.payment_intent_accepted?(stripe_payment_intent)
    end

    def successful?
      payment_method.payment_intent_successful?(stripe_payment_intent)
    end

    def charge_not_required?
      payment_method.payment_intent_charge_not_required?(stripe_payment_intent)
    end

    # Warms everything settlement reads from Stripe — the intent, its charge,
    # and the gateway customer a card source needs — so the webhook path's
    # locked settlement does no Stripe I/O.
    def prepare_for_settlement!
      stripe_charge
      payment_method.fetch_or_create_customer(order: owner) if owner&.customer
      self
    end

    # Core creates the payment; Stripe only says what instrument it was paid
    # with. The charge and customer are already warmed by
    # +prepare_for_settlement!+, so this does no Stripe I/O inside the lock.
    #
    # @return [Spree::PaymentSource, nil]
    def payment_source_for_settlement
      charge = stripe_charge

      if charge.present?
        SpreeStripe::CreateSource.new(
          owner: owner,
          stripe_payment_method_details: charge.payment_method_details,
          stripe_payment_method_id: charge.payment_method,
          stripe_billing_details: charge.billing_details,
          gateway: payment_method
        ).call
      elsif charge_not_required?
        # Bank transfers settle with no charge object, so the instrument has
        # to come off the intent instead.
        intent = stripe_payment_intent

        SpreeStripe::CreateSource.new(
          owner: owner,
          stripe_payment_method_details: intent.payment_method,
          stripe_payment_method_id: intent.payment_method.id,
          stripe_billing_details: nil,
          gateway: payment_method
        ).call
      end
    end

    # Keeps the charge reference alongside whatever the caller passed.
    def apply_settlement_metadata(payment, metadata)
      super
      charge = stripe_charge
      payment.metadata['stripe_charge_id'] = charge.id if charge.present?
    end
  end
end
