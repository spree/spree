module SpreeStripe
  # Stripe payment gateway built on the payment session API. Payment intents are
  # created and confirmed through sessions; core's payment lifecycle then drives
  # capture, refund and cancellation against the resulting intent.
  class Gateway < ::Spree::Gateway
    include SpreeStripe::Gateway::PaymentSessions
    include SpreeStripe::Gateway::PaymentSetupSessions
    include SpreeStripe::Gateway::Webhooks
    include SpreeStripe::Gateway::Connect

    preference :publishable_key, :password
    preference :secret_key, :password

    validates :preferred_secret_key, :preferred_publishable_key, presence: true
    validate :validate_secret_key, unless: -> { Rails.env.test? }, if: -> { preferred_secret_key.present? }

    def provider_class
      self.class
    end

    def default_name
      'Stripe'
    end

    def method_type
      'spree_stripe'
    end

    def payment_icon_name
      'stripe'
    end

    def payment_profiles_supported?
      true
    end

    def gateway_dashboard_payment_url(payment)
      return if payment.transaction_id.blank?

      "https://dashboard.stripe.com/payments/#{payment.transaction_id}"
    end

    # Called by core when a session-created payment moves to pending. The intent
    # is already confirmed client-side in the session flow, so this reads back the
    # intent rather than initiating a charge.
    #
    # @param amount_in_cents [Integer]
    # @param payment_source [Spree::PaymentSource, Spree::CreditCard]
    # @param gateway_options [Hash] Spree::Payment::GatewayOptions#to_hash
    # @return [Spree::PaymentResponse]
    def authorize(amount_in_cents, payment_source, gateway_options = {})
      handle_authorize_or_purchase(amount_in_cents, payment_source, gateway_options)
    end

    # @see #authorize — capture vs authorize is decided by the intent's capture
    #   method, so both resolve the same way.
    def purchase(amount_in_cents, payment_source, gateway_options = {})
      handle_authorize_or_purchase(amount_in_cents, payment_source, gateway_options)
    end

    def capture(amount_in_cents, payment_intent_id, _gateway_options = {})
      protect_from_error do
        stripe_payment_intent = retrieve_payment_intent(payment_intent_id)

        response = if payment_intent_requires_capture?(stripe_payment_intent)
                     capture_payment_intent(payment_intent_id, amount_in_cents)
                   elsif stripe_payment_intent.status == 'succeeded'
                     stripe_payment_intent
                   else
                     raise Spree::Core::GatewayError, "Payment intent status is #{stripe_payment_intent.status}"
                   end

        success(response.id, response)
      end
    end

    def credit(amount_in_cents, _source, payment_intent_id, _gateway_options = {})
      protect_from_error do
        response = send_request do |opts|
          Stripe::Refund.create({ amount: amount_in_cents, payment_intent: payment_intent_id }, opts)
        end

        success(response.id, response)
      end
    end

    def void(response_code, _source, _gateway_options)
      return failure('Response code is blank') if response_code.blank?

      protect_from_error do
        response = cancel_payment_intent(response_code)
        success(response.id, response)
      end
    end

    # A completed payment can no longer be voided, so cancellation refunds it
    # instead. Refunds for a fulfillment are skipped — the delivery cost is
    # refunded as a whole elsewhere.
    def cancel(payment_intent_id, payment = nil)
      protect_from_error do
        if payment&.completed?
          amount = payment.credit_allowed
          return success(payment_intent_id, {}) if amount.zero?
          return success(payment_intent_id, {}) if payment.respond_to?(:for_shipment?) && payment.for_shipment?

          # One refund path for the whole system — Refunds::Create owns the
          # balance check, the credit, the compensation and the hooks. Store
          # passed explicitly: cancellation runs from jobs and webhooks where
          # Spree::Current.store is nil, and the bare reason lookup would mint
          # a storeless row.
          result = Spree.refund_create_workflow.call(
            payment: payment,
            reason: Spree::RefundReason.order_canceled_reason(payment.owner.store),
            refunder: payment.order.canceler
          )
          raise Spree::Core::GatewayError, result.error.value.to_s if result.failure?

          # Spree::Refund#response holds the `credit` response. The authorization
          # must stay the payment intent id, or the refund id would overwrite it.
          success(payment.response_code, result.value.response.params)
        else
          response = cancel_payment_intent(payment_intent_id)
          success(response.id, response)
        end
      end
    end

    # @param order [Spree::Cart, Spree::Order, nil]
    # @param customer [Spree::Customer, nil]
    # @return [Spree::GatewayCustomer, nil]
    def fetch_or_create_customer(order: nil, customer: nil)
      customer ||= order&.customer
      return nil if customer.blank?

      gateway_customers.find_by(customer: customer) || create_customer(order: order, customer: customer)
    end

    # @return [Spree::GatewayCustomer]
    def create_customer(order: nil, customer: nil)
      customer ||= order&.customer
      payload = build_customer_payload(order: order, customer: customer)
      response = send_request { |opts| Stripe::Customer.create(payload, opts) }

      gateway_customer = gateway_customers.build(customer: customer, profile_id: response.id)
      gateway_customer.save! if customer.present?
      gateway_customer
    end

    def update_customer(order: nil, customer: nil)
      customer ||= order&.customer
      return if customer.blank?

      gateway_customer = gateway_customers.find_by(customer: customer)
      return if gateway_customer.blank?

      payload = build_customer_payload(order: order, customer: customer)
      send_request { |opts| Stripe::Customer.update(gateway_customer.profile_id, payload, opts) }
    end

    def retrieve_charge(charge_id)
      send_request { |opts| Stripe::Charge.retrieve(charge_id, opts) }
    end

    def create_ephemeral_key(customer_profile_id)
      protect_from_error do
        response = send_request do |opts|
          Stripe::EphemeralKey.create({ customer: customer_profile_id }, opts.merge(stripe_version: Stripe.api_version))
        end

        success(response.secret, response)
      end
    end

    def create_setup_intent(customer_profile_id)
      protect_from_error do
        response = send_request do |opts|
          Stripe::SetupIntent.create({ customer: customer_profile_id, automatic_payment_methods: { enabled: true } }, opts)
        end

        success(response.client_secret, response)
      end
    end

    # Stripe reports address and CVC checks as pass/fail/unchecked on the
    # payment method; CreateSource stores them in the source's metadata. This
    # translates them to the AVS/CVV response codes core's risk analysis reads.
    AVS_CODES = {
      'pass' => { 'pass' => 'Y', 'fail' => 'A', 'unchecked' => 'B' },
      'fail' => { 'pass' => 'Z', 'fail' => 'N' },
      'unchecked' => { 'pass' => 'P', 'unchecked' => 'I' }
    }.freeze

    CVV_CODES = { 'pass' => 'M', 'fail' => 'N', 'unchecked' => 'P' }.freeze

    # @param source [Spree::PaymentSource, Spree::CreditCard]
    # @return [Hash, nil]
    def risk_codes_for(source)
      return unless source.is_a?(Spree::CreditCard)

      checks = source.metadata[:checks]
      return if checks.blank?

      {
        avs_response: AVS_CODES.dig(checks[:address_line1_check], checks[:address_postal_code_check]),
        cvv_response_code: CVV_CODES[checks[:cvc_check]]
      }
    end

    def create_profile(payment)
      gateway_customer = fetch_or_create_customer(order: payment.order)
      return if payment.source.blank? || gateway_customer.blank?

      payment.source.update(gateway_customer_profile_id: gateway_customer.profile_id)
    end

    def api_options
      { api_key: preferred_secret_key }
    end

    def send_request
      yield(api_options)
    end

    private

    def handle_authorize_or_purchase(amount_in_cents, _payment_source, gateway_options)
      # Scoped through this gateway's own payments — a cart-owned payment
      # (checkout is still in flight) has no order to join through, and the
      # payment method already belongs to exactly one store. Found by the
      # prefixed id: the derived `R1001-P1` number cannot be queried (its
      # column is NULL on 6.0 rows). The stored-number lookup remains only
      # for legacy rows and callers still passing pre-6.0 options.
      prefixed_id = gateway_options[:payment_prefixed_id]
      payment = prefixed_id.present? ? payments.find_by_prefix_id(prefixed_id) : nil

      if payment.blank?
        payment_number = gateway_options[:payment_id].presence || gateway_options[:order_id]
        return failure('Payment number is invalid') if payment_number.blank?

        payment = payments.find_by(number: payment_number)
      end
      return failure('Payment not found') if payment.blank?
      return failure('Payment is missing a payment intent') if payment.response_code.blank?

      protect_from_error do
        stripe_payment_intent = retrieve_payment_intent(payment.response_code)

        response = if payment_intent_accepted?(stripe_payment_intent)
                     # already confirmed via the session flow
                     stripe_payment_intent
                   else
                     confirm_payment_intent(stripe_payment_intent.id)
                   end

        success(response.id, response)
      end
    end

    def validate_secret_key
      Stripe::Refund.list({ limit: 0 }, api_options)
    rescue Stripe::AuthenticationError
      errors.add(:base, 'Secret key is invalid')
    rescue Stripe::PermissionError => e
      errors.add(:base, 'You have provided your publishable key instead of your secret key') if e.error&.code == 'secret_key_required'
    rescue Stripe::StripeError
      errors.add(:base, 'Something went wrong with Stripe. Try again later.')
    end

    def build_customer_payload(order: nil, customer: nil)
      customer ||= order&.customer
      address = order&.bill_address || customer&.bill_address
      name = order&.name || customer&.full_name
      email = order&.email || customer&.email

      SpreeStripe::CustomerPresenter.new(name: name, email: email, address: address).call
    end

    def success(authorization, full_response)
      Spree::PaymentResponse.new(true, nil, full_response.as_json, authorization: authorization)
    end

    def failure(error = nil)
      Spree::PaymentResponse.new(false, error)
    end

    def protect_from_error
      yield
    rescue Stripe::StripeError => e
      raise Spree::Core::GatewayError, e.message
    end
  end
end
