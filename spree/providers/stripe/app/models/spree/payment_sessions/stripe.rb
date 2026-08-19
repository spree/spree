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

    # Builds the payment together with a Stripe-specific source (card, Klarna,
    # SEPA, …), which core's generic implementation cannot do.
    def find_or_create_payment!(metadata = {})
      return unless persisted?
      return payment if payment.present?

      SpreeStripe::CreatePayment.new(
        owner: owner,
        payment_session: self,
        gateway: payment_method,
        amount: amount
      ).call
    end
  end
end
