module SpreeStripe
  # Reuses the pending Stripe payment session (keeping its amount in sync with
  # the total) or creates a new one.
  class CreatePaymentSession
    # @param owner [Spree::Cart, Spree::Order]
    # @param gateway [SpreeStripe::Gateway]
    # @return [Spree::PaymentSessions::Stripe, nil]
    def call(owner, gateway)
      amount = owner.total_minus_store_credits
      return if Spree::Money.new(amount, currency: owner.currency).cents.zero?

      session = owner.payment_sessions.where(payment_method: gateway, status: 'pending').order(:created_at).last

      return gateway.create_payment_session(order: owner) unless session

      gateway.update_payment_session(payment_session: session, amount: amount) if session.amount != amount
      session
    end
  end
end
