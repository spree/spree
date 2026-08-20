module SpreeStripe
  # @deprecated Unused since 6.0 and removed in 7.0. Core's
  #   Spree::PaymentSession#find_or_create_payment! creates the payment now;
  #   this gem only supplies the source, through
  #   Spree::PaymentSessions::Stripe#payment_source_for_settlement.
  #
  #   It diverged from core in three ways that this consolidation fixed: it
  #   never set skip_source_requirement (so a session with no charge raised
  #   "Source can't be blank"), it keyed idempotency on the amount as well as
  #   the intent (so an amount change minted a second payment), and it did not
  #   rescue RecordNotUnique (so the webhook/return race could crash).
  class CreatePayment
    # @param owner [Spree::Cart, Spree::Order]
    # @param payment_session [Spree::PaymentSessions::Stripe]
    # @param gateway [SpreeStripe::Gateway] the session's payment method
    def initialize(owner:, payment_session:, gateway:, amount: nil)
      @owner = owner
      @gateway = gateway
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
      payment.metadata['stripe_charge_id'] = stripe_charge.id if stripe_charge.present?
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
