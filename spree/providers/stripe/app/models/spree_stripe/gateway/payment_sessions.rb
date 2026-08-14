module SpreeStripe
  class Gateway < ::Spree::Gateway
    # A Stripe payment session is a Stripe payment intent: creating the session
    # creates the intent, and the session stores its id as the external id.
    # Intents are Stripe-side API objects — there is no intent record in Spree.
    module PaymentSessions
      extend ActiveSupport::Concern

      # Banks confirm these asynchronously, so `processing` is as good as accepted.
      DELAYED_NOTIFICATION_PAYMENT_METHOD_TYPES = %w[sepa_debit us_bank_account].freeze
      # Funds arrive out of band, leaving the intent in `requires_action`.
      BANK_PAYMENT_METHOD_TYPES = %w[customer_balance us_bank_account].freeze
      # next_action.type Stripe sets while an ACH debit awaits verification.
      MICRODEPOSIT_VERIFICATION_ACTION = 'verify_with_microdeposits'.freeze
      MANUAL_CAPTURE_METHOD = 'manual'.freeze
      SETUP_FUTURE_USAGE = 'off_session'.freeze

      def session_required?
        true
      end

      def payment_session_class
        Spree::PaymentSessions::Stripe
      end

      # @param order [Spree::Cart, Spree::Order]
      # @return [Spree::PaymentSessions::Stripe]
      def create_payment_session(order:, amount: nil, external_data: {})
        total = amount.presence || order.total_minus_store_credits
        amount_in_cents = Spree::Money.new(total, currency: order.currency).cents

        raise Spree::Core::GatewayError, Spree.t('stripe.payment_session_errors.zero_amount') if amount_in_cents.zero?

        gateway_customer = fetch_or_create_customer(order: order)
        stripe_payment_method_id = external_data[:stripe_payment_method_id] || external_data['stripe_payment_method_id']

        response = create_payment_intent(
          amount_in_cents, order,
          payment_method_id: stripe_payment_method_id,
          customer_profile_id: gateway_customer&.profile_id
        )

        ephemeral_key_response = create_ephemeral_key(gateway_customer.profile_id) if gateway_customer.present?

        payment_session_class.create!(
          owner: order,
          payment_method: self,
          amount: total,
          currency: order.currency,
          status: 'pending',
          external_id: response.authorization,
          customer: order.customer,
          customer_external_id: gateway_customer&.profile_id,
          external_data: {
            'client_secret' => response.params['client_secret'],
            'ephemeral_key_secret' => ephemeral_key_response&.params&.dig('secret'),
            'stripe_payment_method_id' => stripe_payment_method_id
          }.compact
        )
      end

      def update_payment_session(payment_session:, amount: nil, external_data: {})
        attrs = {}
        amount_in_cents = nil

        if amount.present?
          attrs[:amount] = amount
          amount_in_cents = Spree::Money.new(amount, currency: payment_session.currency).cents
        end

        stripe_payment_method_id = external_data[:stripe_payment_method_id] || external_data['stripe_payment_method_id']

        update_payment_intent(
          payment_session.external_id,
          amount_in_cents || payment_session.amount_in_cents,
          payment_session.owner,
          stripe_payment_method_id
        )

        attrs[:external_data] = (payment_session.external_data || {}).merge(external_data.stringify_keys) if external_data.present?

        payment_session.update!(attrs) if attrs.any?
      end

      # Verifies the intent with Stripe, creates the Payment record and patches
      # wallet address data.
      #
      # Does NOT complete the order — Carts::Complete owns that.
      def complete_payment_session(payment_session:, params: {})
        stripe_payment_intent = retrieve_payment_intent(payment_session.external_id)

        unless payment_intent_accepted?(stripe_payment_intent)
          payment_session.fail if payment_session.can_fail?
          return payment_session
        end

        payment_session.process if payment_session.can_process?

        charge = payment_session.stripe_charge
        patch_wallet_address(payment_session.owner, charge) if charge.present?

        # `succeeded` is the only status where funds have moved. The other
        # accepted statuses — requires_capture (manual capture), processing
        # (delayed-notification banks), requires_action (bank transfer awaiting
        # funds) — settle as authorization-only, completed later by webhook or
        # explicit capture.
        payment_session.settle_payment!(captured: payment_intent_successful?(stripe_payment_intent))

        payment_session.complete unless payment_session.completed?
        payment_session
      end

      def retrieve_payment_intent(payment_intent_id)
        send_request { |opts| Stripe::PaymentIntent.retrieve({ id: payment_intent_id, expand: ['payment_method'] }, opts) }
      end

      def confirm_payment_intent(payment_intent_id)
        send_request { |opts| Stripe::PaymentIntent.confirm(payment_intent_id, {}, opts) }
      end

      def capture_payment_intent(payment_intent_id, amount_in_cents)
        send_request { |opts| Stripe::PaymentIntent.capture(payment_intent_id, { amount_to_capture: amount_in_cents }, opts) }
      end

      def cancel_payment_intent(payment_intent_id)
        send_request { |opts| Stripe::PaymentIntent.cancel(payment_intent_id, {}, opts) }
      end

      # Whether the intent has progressed far enough to record a payment. The
      # acceptable statuses depend on how the money moves: manual capture stops
      # at `requires_capture`, delayed-notification banks sit in `processing`,
      # and bank transfers wait for funds in `requires_action`.
      def payment_intent_accepted?(payment_intent)
        statuses = %w[succeeded]
        statuses << 'requires_capture' if payment_intent_manual_capture?(payment_intent)
        statuses << 'processing' if payment_intent_type_in?(payment_intent, DELAYED_NOTIFICATION_PAYMENT_METHOD_TYPES)
        statuses << 'requires_action' if payment_intent_charge_not_required?(payment_intent) &&
                                         !payment_intent_awaiting_microdeposits?(payment_intent)

        payment_intent.status.in?(statuses)
      end

      def payment_intent_successful?(payment_intent)
        payment_intent.status == 'succeeded'
      end

      def payment_intent_requires_capture?(payment_intent)
        payment_intent.status == 'requires_capture'
      end

      # Bank transfers settle without a charge object, so the payment source has
      # to be built from the intent instead.
      def payment_intent_charge_not_required?(payment_intent)
        payment_intent_type_in?(payment_intent, BANK_PAYMENT_METHOD_TYPES)
      end

      # ACH debits sit in requires_action until the customer confirms the two
      # microdeposit amounts. Funds are not on their way yet, so the session
      # must not settle — Stripe reports the eventual outcome by webhook.
      def payment_intent_awaiting_microdeposits?(payment_intent)
        next_action = payment_intent.try(:next_action)
        return false unless next_action.respond_to?(:type)

        next_action.type.to_s == MICRODEPOSIT_VERIFICATION_ACTION
      end

      def payment_intent_manual_capture?(payment_intent)
        payment_intent.respond_to?(:capture_method) && payment_intent.capture_method == MANUAL_CAPTURE_METHOD
      end

      private

      # @param order [Spree::Cart, Spree::Order]
      # @return [Spree::PaymentResponse]
      def create_payment_intent(amount_in_cents, order, payment_method_id: nil, customer_profile_id: nil)
        payload = {
          amount: amount_in_cents,
          currency: order.currency,
          customer: customer_profile_id,
          payment_method: payment_method_id,
          # Stripe knows only "charge now" or "authorize now, capture later",
          # so both on_dispatch and manual map to its manual capture.
          capture_method: (MANUAL_CAPTURE_METHOD unless capture_at_checkout?),
          statement_descriptor_suffix: statement_descriptor_suffix_for(order),
          automatic_payment_methods: { enabled: true },
          transfer_group: order.number,
          metadata: { spree_order_id: order.id },
          shipping: shipping_payload(order.ship_address)
        }.compact

        # A saved payment method is already tokenized; a new one is stored so it
        # can be charged off-session later.
        payload[:payment_method_options] = {
          card: { setup_future_usage: SETUP_FUTURE_USAGE },
          sepa_debit: { setup_future_usage: SETUP_FUTURE_USAGE }
        } if payment_method_id.blank?

        protect_from_error do
          response = send_request { |opts| Stripe::PaymentIntent.create(payload, opts) }

          success(response.id, response)
        end
      end

      # Only the fields that can legitimately change while a session is pending.
      def update_payment_intent(payment_intent_id, amount_in_cents, order, payment_method_id = nil)
        protect_from_error do
          payload = {
            amount: amount_in_cents,
            currency: order.currency,
            customer: fetch_or_create_customer(order: order)&.profile_id,
            payment_method: payment_method_id,
            shipping: shipping_payload(order.ship_address)
          }.compact

          response = send_request { |opts| Stripe::PaymentIntent.update(payment_intent_id, payload, opts) }

          success(response.id, response)
        end
      end

      # Stripe requires address1 on a shipping address; Spree does not always
      # demand one, so an incomplete address is omitted rather than rejected.
      #
      # @return [Hash, nil]
      def shipping_payload(ship_address)
        return if ship_address.blank?

        # Validated on a duplicate: `invalid?` populates errors on the record,
        # and clearing them afterwards would still stomp whatever the caller
        # had collected on the live address.
        return if ship_address.address1.blank? || ship_address.dup.invalid?

        {
          address: {
            city: ship_address.city,
            country: ship_address.country_iso,
            line1: ship_address.address1,
            line2: ship_address.address2,
            postal_code: ship_address.zipcode,
            state: ship_address.state_abbr
          },
          name: ship_address.full_name
        }
      end

      def statement_descriptor_suffix_for(order)
        SpreeStripe::StatementDescriptorSuffixPresenter.new(order_description: order.number).call
      end

      def payment_intent_type_in?(payment_intent, types)
        payment_method = payment_intent.payment_method
        return false unless payment_method.respond_to?(:type)

        payment_method.type.in?(types)
      end

      # Quick checkout (Apple Pay / Google Pay) confirms payment before the
      # storefront has a billing address, so it arrives on the Stripe charge.
      #
      # @param owner [Spree::Cart, Spree::Order]
      def patch_wallet_address(owner, charge)
        return if charge.blank?

        billing_details = charge.billing_details
        address = billing_details.address

        owner.email ||= billing_details.email
        owner.save! if owner.email_changed?

        return if owner.bill_address.present? && owner.bill_address.valid?

        country_iso = address.country
        country = (country_iso.present? && Spree::Country.by_iso(country_iso)) ||
                  owner.store.default_market&.default_country ||
                  Spree::Country.by_iso('US')

        owner.bill_address ||= Spree::Address.new(country: country, customer: owner.customer)
        owner.bill_address.quick_checkout = true

        # Google Pay sometimes omits the name entirely.
        first_name = billing_details.name&.split(' ')&.first || owner.ship_address&.first_name || owner.customer&.first_name
        last_name = billing_details.name&.split(' ')&.last || owner.ship_address&.last_name || owner.customer&.last_name

        owner.bill_address.first_name ||= first_name
        owner.bill_address.last_name ||= last_name
        owner.bill_address.phone ||= billing_details.phone
        owner.bill_address.address1 ||= address.line1
        owner.bill_address.address2 ||= address.line2
        owner.bill_address.city ||= address.city
        owner.bill_address.zipcode ||= address.postal_code

        state_name = address.state
        if country.states_required?
          owner.bill_address.state = country.states.find_all_by_name_or_abbr(state_name)&.first
        else
          owner.bill_address.state_name = state_name
        end
        owner.bill_address.state_name ||= state_name

        if owner.bill_address.invalid?
          return if owner.ship_address.blank?

          owner.bill_address = owner.ship_address
        end

        owner.bill_address.save! if owner.bill_address&.changed?
        owner.save!

        copy_bill_info_to_customer(owner) if owner.customer.present?
      end

      def copy_bill_info_to_customer(owner)
        customer = owner.customer
        customer.first_name ||= owner.bill_address.first_name
        customer.last_name ||= owner.bill_address.last_name
        customer.phone ||= owner.bill_address.phone
        customer.bill_address_id ||= owner.bill_address.id
        customer.save! if customer.changed?
      end
    end
  end
end
