module SpreeStripe
  class Gateway < ::Spree::Gateway
    module PaymentSessions
      extend ActiveSupport::Concern

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

        raise Spree::Core::GatewayError, I18n.t('spree.stripe.payment_session_errors.zero_amount') if amount_in_cents.zero?

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

        payment_session.find_or_create_payment!

        payment = payment_session.payment
        if payment.present? && !payment.completed?
          # The `else` covers requires_capture (manual capture), processing
          # (delayed-notification banks) and requires_action (bank transfer
          # awaiting funds) — all authorization-only states.
          if payment_intent_successful?(stripe_payment_intent)
            payment.process!
          else
            payment.authorize!
          end
        end

        payment_session.complete unless payment_session.completed?
        payment_session
      end

      private

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
