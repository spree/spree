module SpreeStripe
  # Maps a Stripe payment method onto the matching Spree payment source.
  class CreateSource
    def initialize(stripe_payment_method_details:, stripe_payment_method_id:, gateway:, stripe_billing_details:, owner: nil, customer: nil)
      @stripe_payment_method_details = stripe_payment_method_details
      @stripe_payment_method_id = stripe_payment_method_id
      @gateway = gateway
      @customer = customer || owner&.customer
      @stripe_billing_details = stripe_billing_details
      @owner = owner
    end

    # @return [Spree::PaymentSource]
    def call
      case stripe_payment_method_details.type
      when 'card'
        find_or_create_credit_card
      when 'klarna'
        SpreeStripe::PaymentSources::Klarna.create!(source_params)
      when 'afterpay_clearpay'
        SpreeStripe::PaymentSources::AfterPay.create!(source_params)
      when 'sepa_debit'
        SpreeStripe::PaymentSources::SepaDebit.create!(source_params)
      when 'p24'
        SpreeStripe::PaymentSources::Przelewy24.create!(source_params.merge(bank: stripe_payment_method_details.p24.bank))
      when 'ideal'
        SpreeStripe::PaymentSources::Ideal.create!(
          source_params.merge(
            bank: stripe_payment_method_details.ideal.bank,
            last4: stripe_payment_method_details.ideal.iban_last4
          )
        )
      when 'alipay'
        SpreeStripe::PaymentSources::Alipay.create!(source_params)
      when 'link'
        SpreeStripe::PaymentSources::Link.create!(source_params)
      when 'affirm'
        SpreeStripe::PaymentSources::Affirm.create!(source_params)
      when 'customer_balance', 'us_bank_account'
        SpreeStripe::PaymentSources::BankTransfer.create!(source_params)
      else
        Spree::PaymentSource.create!(source_params)
      end
    end

    private

    attr_reader :gateway, :customer, :stripe_payment_method_details, :stripe_payment_method_id,
                :stripe_billing_details, :owner

    def find_or_create_credit_card
      if customer
        exact_source = customer.credit_cards.find_by(gateway_payment_profile_id: stripe_payment_method_id)
        return exact_source if exact_source

        matching_source = match_credit_card_by_fingerprint
        return matching_source if matching_source
      end

      Spree::CreditCard.create!(credit_card_params)
    end

    # Stripe issues a fresh PaymentMethod id every time a card is entered, even
    # for the same physical card, so matching on the profile id alone would save
    # a duplicate. The card fingerprint is stable, so match on it plus expiry.
    #
    # @return [Spree::CreditCard, nil]
    def match_credit_card_by_fingerprint
      card = stripe_payment_method_details.card
      return if card.fingerprint.blank?

      customer.credit_cards.
        where(payment_method: gateway).
        by_fingerprint(card.fingerprint, card.exp_month, card.exp_year).
        order(created_at: :desc).
        first
    end

    def credit_card_params
      card_details = stripe_payment_method_details.card
      gateway_customer = gateway.fetch_or_create_customer(customer: customer, order: owner)

      {
        customer: customer,
        gateway_customer: gateway_customer,
        payment_method: gateway,
        gateway_customer_profile_id: gateway_customer&.profile_id,
        gateway_payment_profile_id: stripe_payment_method_id,
        fingerprint: card_details.fingerprint,
        name: stripe_billing_details&.name,
        month: card_details.exp_month,
        year: card_details.exp_year,
        last_digits: card_details.last4,
        brand: card_details.brand,
        metadata: {
          checks: card_details&.checks,
          wallet: { type: card_details&.wallet&.type }
        }
      }
    end

    def source_params
      {
        gateway_payment_profile_id: stripe_payment_method_id,
        payment_method: gateway
      }
    end
  end
end
