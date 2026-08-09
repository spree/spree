module SpreeStripe
  # Builds the Spree::Payment for a completed payment session, together with the
  # Stripe-specific payment source.
  class CreatePayment
    # @param owner [Spree::Cart, Spree::Order]
    # @param payment_session [Spree::PaymentSessions::Stripe]
    # @param gateway [SpreeStripe::Gateway]
    def initialize(owner:, payment_session:, gateway: nil, amount: nil)
      @owner = owner
      @gateway = gateway || owner.store.stripe_gateway
      @payment_session = payment_session
      @amount = amount || owner.total_minus_store_credits
    end

    # @return [Spree::Payment]
    def call
      stripe_charge = payment_session.stripe_charge
      source = build_source(stripe_charge)

      # A retried job must not produce a second payment for the same intent.
      payment = owner.payments.find_or_initialize_by(
        payment_method_id: gateway.id,
        response_code: payment_session.stripe_id,
        amount: amount
      )

      payment.source = source if source.present?
      payment.stripe_charge_id = stripe_charge&.id
      payment.save!
      payment
    end

    private

    attr_reader :owner, :gateway, :payment_session, :amount

    def build_source(stripe_charge)
      if stripe_charge.present?
        SpreeStripe::CreateSource.new(
          owner: owner,
          stripe_payment_method_details: stripe_charge.payment_method_details,
          stripe_payment_method_id: stripe_charge.payment_method,
          stripe_billing_details: stripe_charge.billing_details,
          gateway: gateway
        ).call
      elsif payment_session.charge_not_required?
        stripe_payment_intent = payment_session.stripe_payment_intent

        SpreeStripe::CreateSource.new(
          owner: owner,
          stripe_payment_method_details: stripe_payment_intent.payment_method,
          stripe_payment_method_id: stripe_payment_intent.payment_method.id,
          stripe_billing_details: nil,
          gateway: gateway
        ).call
      end
    end
  end
end
