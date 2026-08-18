require 'spec_helper'

RSpec.describe SpreeStripe::Gateway::PaymentSessions do
  let(:store) { @default_store }
  let(:customer) { create(:customer) }
  let(:order) { create(:order_with_line_items, store: store, customer: customer) }
  let(:gateway) { create(:stripe_gateway, store: store) }

  let(:gateway_customer) { instance_double(Spree::GatewayCustomer, profile_id: 'cus_test_123') }
  let(:pi_response) do
    Spree::PaymentResponse.new(
      true, nil,
      { 'client_secret' => 'pi_secret_abc' },
      authorization: 'pi_new_intent_123'
    )
  end
  let(:ephemeral_key_response) do
    Spree::PaymentResponse.new(
      true, nil,
      { 'secret' => 'ek_test_secret' },
      authorization: 'ek_test_secret'
    )
  end

  before do
    allow(gateway).to receive(:fetch_or_create_customer).and_return(gateway_customer)
    allow(gateway).to receive(:create_payment_intent).and_return(pi_response)
    allow(gateway).to receive(:create_ephemeral_key).and_return(ephemeral_key_response)
  end

  describe '#session_required?' do
    it 'returns true' do
      expect(gateway.session_required?).to be true
    end
  end

  describe '#payment_session_class' do
    it 'returns Spree::PaymentSessions::Stripe' do
      expect(gateway.payment_session_class).to eq(Spree::PaymentSessions::Stripe)
    end
  end

  describe '#create_payment_session' do
    subject { gateway.create_payment_session(order: order) }

    it 'creates a Stripe PaymentIntent' do
      expect(gateway).to receive(:create_payment_intent).with(
        order.display_total.cents, order,
        payment_method_id: nil,
        customer_profile_id: 'cus_test_123'
      ).and_return(pi_response)
      subject
    end

    it 'creates an ephemeral key' do
      expect(gateway).to receive(:create_ephemeral_key).with('cus_test_123')
      subject
    end

    it 'persists a PaymentSessions::Stripe record' do
      session = subject
      expect(session).to be_a(Spree::PaymentSessions::Stripe)
      expect(session).to be_persisted
      expect(session.external_id).to eq('pi_new_intent_123')
      expect(session.status).to eq('pending')
      expect(session.owner).to eq(order)
      expect(session.payment_method).to eq(gateway)
    end

    it 'stores client_secret and ephemeral_key_secret in external_data' do
      session = subject
      expect(session.external_data['client_secret']).to eq('pi_secret_abc')
      expect(session.external_data['ephemeral_key_secret']).to eq('ek_test_secret')
    end

    it 'stores customer_external_id' do
      session = subject
      expect(session.customer_external_id).to eq('cus_test_123')
    end

    it 'raises a GatewayError when amount is zero' do
      allow(order).to receive(:total_minus_store_credits).and_return(0)
      expect { subject }.to raise_error(Spree::Core::GatewayError, Spree.t('stripe.payment_session_errors.zero_amount'))
    end

    context 'when the owner is a cart' do
      subject { gateway.create_payment_session(order: cart) }

      let(:cart) { create(:cart_with_line_items, store: store, customer: customer) }

      it 'assigns the cart as the owner' do
        session = subject
        expect(session.owner).to eq(cart)
        expect(session.cart).to eq(cart)
        expect(session.order).to be_nil
      end
    end

    context 'with a custom amount' do
      subject { gateway.create_payment_session(order: order, amount: 50.0) }

      it 'uses the provided amount' do
        expect(gateway).to receive(:create_payment_intent).with(
          5000, order,
          payment_method_id: nil,
          customer_profile_id: 'cus_test_123'
        ).and_return(pi_response)
        session = subject
        expect(session.amount).to eq(50.0)
      end
    end

    context 'with external_data containing stripe_payment_method_id' do
      subject { gateway.create_payment_session(order: order, external_data: { stripe_payment_method_id: 'pm_card_visa' }) }

      it 'passes payment_method_id to create_payment_intent' do
        expect(gateway).to receive(:create_payment_intent).with(
          anything, order,
          payment_method_id: 'pm_card_visa',
          customer_profile_id: 'cus_test_123'
        ).and_return(pi_response)
        subject
      end

      it 'stores stripe_payment_method_id in external_data' do
        session = subject
        expect(session.external_data['stripe_payment_method_id']).to eq('pm_card_visa')
      end
    end

    context 'without a customer' do
      before do
        allow(gateway).to receive(:fetch_or_create_customer).and_return(nil)
      end

      it 'does not create an ephemeral key' do
        expect(gateway).not_to receive(:create_ephemeral_key)
        subject
      end

      it 'creates the session without customer data' do
        session = subject
        expect(session.customer_external_id).to be_nil
      end
    end
  end

  describe '#update_payment_session' do
    let(:payment_session) do
      create(:stripe_payment_session,
             owner: order,
             payment_method: gateway,
             amount: 20.0,
             external_id: 'pi_existing_123',
             external_data: { 'client_secret' => 'pi_secret_old' })
    end

    before do
      allow(gateway).to receive(:update_payment_intent)
    end

    it 'calls update_payment_intent on Stripe' do
      expect(gateway).to receive(:update_payment_intent).with(
        'pi_existing_123', 3000, order, nil
      )
      gateway.update_payment_session(payment_session: payment_session, amount: 30.0)
    end

    it 'updates the session amount' do
      gateway.update_payment_session(payment_session: payment_session, amount: 30.0)
      expect(payment_session.reload.amount).to eq(30.0)
    end

    it 'merges new external_data' do
      gateway.update_payment_session(
        payment_session: payment_session,
        external_data: { stripe_payment_method_id: 'pm_new' }
      )
      expect(payment_session.reload.external_data['stripe_payment_method_id']).to eq('pm_new')
      expect(payment_session.external_data['client_secret']).to eq('pi_secret_old')
    end
  end

  describe '#complete_payment_session' do
    let(:payment_session) do
      create(:stripe_payment_session,
             owner: order,
             payment_method: gateway,
             amount: order.total,
             external_id: 'pi_complete_123')
    end

    # Wallet charges carry a full billing address; the fields the storefront
    # never collected are what patch_wallet_address fills in.
    def build_charge(billing_overrides = {}, address_overrides = {})
      default_address = {
        line1: '100 California Street', line2: nil, city: 'San Francisco',
        state: 'CA', postal_code: '94111', country: 'US'
      }
      default_billing = { name: 'John Doe', email: 'john@example.com', phone: nil }

      Stripe::StripeObject.construct_from(
        id: 'ch_test_123',
        payment_method: 'pm_test_123',
        billing_details: default_billing.merge(billing_overrides).merge(
          address: default_address.merge(address_overrides)
        ),
        payment_method_details: { type: 'card', card: { brand: 'visa', last4: '4242', exp_month: 12, exp_year: 2025 } }
      )
    end

    let(:stripe_charge) { build_charge }

    context 'when the payment intent is accepted and succeeded' do
      let(:stripe_pi) { Stripe::StripeObject.construct_from(id: 'pi_complete_123', status: 'succeeded', latest_charge: 'ch_test_123', payment_method: { type: 'card' }) }
      let(:payment) { create(:payment, order: order, payment_method: gateway, amount: order.total, state: 'checkout') }

      before do
        allow(gateway).to receive(:retrieve_payment_intent).and_return(stripe_pi)
        allow(gateway).to receive(:retrieve_charge).and_return(stripe_charge)
        allow(payment_session).to receive(:find_or_create_payment!).and_return(payment)
      end

      it 'completes the session' do
        gateway.complete_payment_session(payment_session: payment_session)
        expect(payment_session.reload.status).to eq('completed')
      end

      it 'completes the payment with a capture event' do
        gateway.complete_payment_session(payment_session: payment_session)

        expect(payment.reload).to be_completed
        expect(payment.capture_events.sum(:amount)).to eq(payment.amount)
      end

      describe 'wallet billing address patching' do
        context 'when the charge billing address has a known country ISO' do
          let!(:california) do
            usa = Spree::Country.by_iso('US')
            usa.states.find { |state| state.abbr == 'CA' }
          end

          it 'builds the bill_address from the charge billing details' do
            order.update!(bill_address: nil)

            gateway.complete_payment_session(payment_session: payment_session)

            order.reload
            expect(order.bill_address).to be_present
            expect(order.bill_address.country.iso).to eq('US')
            expect(order.bill_address.address1).to eq('100 California Street')
            expect(order.bill_address.city).to eq('San Francisco')
            expect(order.bill_address.zipcode).to eq('94111')
            expect(order.bill_address.state).to eq(california)
            expect(order.bill_address).to be_quick_checkout
          end

          context 'for a guest order' do
            let(:order) { create(:order_with_line_items, store: store, customer: nil) }

            it 'takes the name from the charge billing details' do
              order.update!(bill_address: nil)

              gateway.complete_payment_session(payment_session: payment_session)

              order.reload
              expect(order.bill_address.first_name).to eq('John')
              expect(order.bill_address.last_name).to eq('Doe')
            end
          end
        end

        context 'when the charge billing address country is nil' do
          let(:stripe_charge) { build_charge({}, country: nil) }

          context 'and the store has a default_market with a default_country' do
            # Great Britain: the charge's address stays valid there (no
            # subdivision required), so the fallback country actually survives
            # the address validation instead of degrading to the ship address.
            let(:default_country) { Spree::Country.by_iso('GB') }

            # The store's real default market, repointed. Stubbing cannot work
            # here: the flow reloads the order, so it sees the database rather
            # than any in-memory double.
            before do
              order.store.default_market.update!(countries: [default_country])
            end

            it 'falls back to the store default_market default_country' do
              order.update!(bill_address: nil)

              gateway.complete_payment_session(payment_session: payment_session)

              order.reload
              expect(order.bill_address).to be_present
              expect(order.bill_address.country_code).to eq(default_country.iso)
            end
          end

          context 'and the store has no default_market' do
            before do
              allow_any_instance_of(Spree::Store).to receive(:default_market).and_return(nil)
            end

            it 'falls back to the US country as last resort' do
              order.update!(bill_address: nil)

              gateway.complete_payment_session(payment_session: payment_session)

              order.reload
              expect(order.bill_address).to be_present
              expect(order.bill_address.country.iso).to eq('US')
            end
          end
        end

        context 'when the charge billing address country is an unknown ISO' do
          let(:stripe_charge) { build_charge({}, country: 'ZZ') }

          it 'ignores the unknown ISO and falls back through the chain' do
            order.update!(bill_address: nil)

            gateway.complete_payment_session(payment_session: payment_session)

            order.reload
            expect(order.bill_address).to be_present
            expect(order.bill_address.country.iso).to eq('US')
          end
        end

        context 'when the order already has a valid bill_address' do
          it 'does not modify the bill_address' do
            original_address = order.bill_address
            expect(original_address).to be_present
            expect(original_address).to be_valid

            gateway.complete_payment_session(payment_session: payment_session)

            expect(order.reload.bill_address_id).to eq(original_address.id)
          end
        end

        context 'when billing_details email fills a missing order email' do
          it 'sets the order email from billing_details' do
            order.update_column(:email, nil)

            gateway.complete_payment_session(payment_session: payment_session)

            expect(order.reload.email).to eq('john@example.com')
          end
        end

        context 'when the latest_charge is missing (no charge to patch from)' do
          let(:stripe_pi) do
            Stripe::StripeObject.construct_from(
              id: 'pi_complete_123',
              status: 'succeeded',
              latest_charge: nil,
              payment_method: { type: 'card' }
            )
          end

          it 'does not raise and still completes the session' do
            order.update!(bill_address: nil)

            expect {
              gateway.complete_payment_session(payment_session: payment_session)
            }.not_to raise_error

            expect(payment_session.reload.status).to eq('completed')
          end
        end
      end
    end

    describe 'accepting a bank-transfer intent' do
      def bank_intent(next_action)
        Stripe::StripeObject.construct_from(
          id: 'pi_bank_123',
          status: 'requires_action',
          payment_method: { type: 'us_bank_account' },
          next_action: next_action
        )
      end

      it 'accepts one that is only awaiting funds' do
        expect(gateway.payment_intent_accepted?(bank_intent(type: 'display_bank_transfer_instructions'))).to be(true)
      end

      # Funds are not on their way until the customer confirms the amounts.
      it 'refuses one still awaiting microdeposit verification' do
        expect(gateway.payment_intent_accepted?(bank_intent(type: 'verify_with_microdeposits'))).to be(false)
      end
    end

    context 'when the payment intent is accepted but not succeeded (requires_action with charge_not_required)' do
      let(:stripe_pi) do
        Stripe::StripeObject.construct_from(
          id: 'pi_complete_123',
          status: 'requires_action',
          latest_charge: 'ch_test_123',
          payment_method: { type: 'card' },
          next_action: { type: 'setup_future_usage' }
        )
      end
      let(:payment) { create(:payment, order: order, payment_method: gateway, amount: order.total, state: 'checkout') }

      before do
        allow(gateway).to receive(:retrieve_payment_intent).and_return(stripe_pi)
        allow(gateway).to receive(:retrieve_charge).and_return(stripe_charge)
        allow(gateway).to receive(:payment_intent_accepted?).and_return(true)
        allow(payment_session).to receive(:find_or_create_payment!).and_return(payment)
      end

      it 'pends the payment instead of capturing it' do
        gateway.complete_payment_session(payment_session: payment_session)

        expect(payment.reload).to be_pending
        expect(payment.capture_events).to be_empty
      end
    end

    context 'when the payment intent is not accepted' do
      let(:stripe_pi) { Stripe::StripeObject.construct_from(id: 'pi_complete_123', status: 'requires_payment_method', payment_method: { type: 'card' }) }

      before do
        allow(gateway).to receive(:retrieve_payment_intent).and_return(stripe_pi)
      end

      it 'fails the session' do
        gateway.complete_payment_session(payment_session: payment_session)
        expect(payment_session.reload.status).to eq('failed')
      end

      it 'does not create a payment' do
        expect(payment_session).not_to receive(:find_or_create_payment!)
        gateway.complete_payment_session(payment_session: payment_session)
      end
    end

    context 'when the payment intent is in requires_capture (manual capture)' do
      let(:stripe_pi) do
        Stripe::StripeObject.construct_from(
          id: 'pi_complete_123',
          status: 'requires_capture',
          capture_method: 'manual',
          latest_charge: nil,
          payment_method: { type: 'card' }
        )
      end
      let(:payment) { create(:payment, order: order, payment_method: gateway, amount: order.total, state: 'checkout') }

      before do
        allow(gateway).to receive(:retrieve_payment_intent).and_return(stripe_pi)
        allow(payment_session).to receive(:find_or_create_payment!).and_return(payment)
      end

      it 'completes the session with the payment pending, not captured' do
        gateway.complete_payment_session(payment_session: payment_session)

        expect(payment_session.reload.status).to eq('completed')
        expect(payment.reload).to be_pending
        expect(payment.capture_events).to be_empty
      end
    end

    # Regression: settlement used to route through the gateway's authorize and
    # purchase verbs, which look the owner up in store.orders — a lookup that
    # can never find a cart, so every checkout-time (cart-owned) settlement
    # failed with 'Order not found'.
    context 'when the session is owned by a cart' do
      let(:cart) { create(:cart_with_line_items, store: store, customer: customer) }
      let(:payment_session) do
        create(:stripe_payment_session, owner: cart, payment_method: gateway, amount: cart.total)
      end
      let(:stripe_pi) do
        Stripe::StripeObject.construct_from(
          id: payment_session.external_id,
          status: 'succeeded',
          latest_charge: 'ch_cart_123',
          payment_method: { type: 'card' }
        )
      end
      let(:cart_charge) do
        Stripe::StripeObject.construct_from(
          id: 'ch_cart_123',
          payment_method: 'pm_cart_123',
          billing_details: {
            name: 'John Doe', email: 'john@example.com', phone: nil,
            address: { line1: '100 California Street', line2: nil, city: 'San Francisco',
                       state: 'CA', postal_code: '94111', country: 'US' }
          },
          payment_method_details: {
            type: 'card',
            card: { brand: 'visa', last4: '4242', exp_month: 12, exp_year: 2035, fingerprint: 'fp_cart',
                    checks: nil, wallet: nil }
          }
        )
      end

      before do
        allow(gateway).to receive(:retrieve_payment_intent).and_return(stripe_pi)
        allow(gateway).to receive(:retrieve_charge).and_return(cart_charge)
        allow(gateway).to receive(:fetch_or_create_customer).and_return(nil)
      end

      it 'settles the payment on the cart' do
        gateway.complete_payment_session(payment_session: payment_session)

        expect(payment_session.reload.status).to eq('completed')
        payment = cart.payments.last
        expect(payment).to be_completed
        expect(payment.response_code).to eq(payment_session.external_id)
      end
    end

    context 'when the session is already completed' do
      let(:stripe_pi) { Stripe::StripeObject.construct_from(id: 'pi_complete_123', status: 'requires_payment_method', payment_method: { type: 'card' }) }

      before do
        payment_session.update_column(:status, 'completed')
        allow(gateway).to receive(:retrieve_payment_intent).and_return(stripe_pi)
      end

      it 'does not fail a completed session' do
        gateway.complete_payment_session(payment_session: payment_session)
        expect(payment_session.reload.status).to eq('completed')
      end
    end
  end

  describe '#parse_webhook_event' do
    let(:raw_body) { '{"id": "evt_test"}' }
    let(:headers) { { 'HTTP_STRIPE_SIGNATURE' => 'sig_test' } }

    context 'with payment_intent.succeeded event' do
      let(:stripe_event) do
        Stripe::StripeObject.construct_from(
          type: 'payment_intent.succeeded',
          data: { object: { id: 'pi_webhook_123' } }
        )
      end
      let!(:payment_session) do
        create(:stripe_payment_session, owner: order, payment_method: gateway, external_id: 'pi_webhook_123')
      end

      before do
        allow(gateway).to receive(:verify_webhook_signature).and_return(stripe_event)
      end

      it 'returns captured action with payment session' do
        result = gateway.parse_webhook_event(raw_body, headers)

        expect(result[:action]).to eq(:captured)
        expect(result[:payment_session]).to eq(payment_session)
      end
    end

    context 'with payment_intent.payment_failed event' do
      let(:stripe_event) do
        Stripe::StripeObject.construct_from(
          type: 'payment_intent.payment_failed',
          data: { object: { id: 'pi_failed_123' } }
        )
      end
      let!(:payment_session) do
        create(:stripe_payment_session, owner: order, payment_method: gateway, external_id: 'pi_failed_123')
      end

      before do
        allow(gateway).to receive(:verify_webhook_signature).and_return(stripe_event)
      end

      it 'returns failed action' do
        result = gateway.parse_webhook_event(raw_body, headers)

        expect(result[:action]).to eq(:failed)
        expect(result[:payment_session]).to eq(payment_session)
      end
    end

    context 'with payment_intent.amount_capturable_updated event' do
      let(:stripe_event) do
        Stripe::StripeObject.construct_from(
          type: 'payment_intent.amount_capturable_updated',
          data: { object: { id: 'pi_authorized_123' } }
        )
      end
      let!(:payment_session) do
        create(:stripe_payment_session, owner: order, payment_method: gateway, external_id: 'pi_authorized_123')
      end

      before do
        allow(gateway).to receive(:verify_webhook_signature).and_return(stripe_event)
      end

      it 'returns authorized action' do
        result = gateway.parse_webhook_event(raw_body, headers)

        expect(result[:action]).to eq(:authorized)
        expect(result[:payment_session]).to eq(payment_session)
      end
    end

    context 'with unsupported event type' do
      let(:stripe_event) do
        Stripe::StripeObject.construct_from(
          type: 'customer.created',
          data: { object: { id: 'cus_123' } }
        )
      end

      before do
        allow(gateway).to receive(:verify_webhook_signature).and_return(stripe_event)
      end

      it 'returns nil' do
        expect(gateway.parse_webhook_event(raw_body, headers)).to be_nil
      end
    end

    context 'when payment session is not found' do
      let(:stripe_event) do
        Stripe::StripeObject.construct_from(
          type: 'payment_intent.succeeded',
          data: { object: { id: 'pi_unknown_123' } }
        )
      end

      before do
        allow(gateway).to receive(:verify_webhook_signature).and_return(stripe_event)
      end

      it 'returns nil' do
        expect(gateway.parse_webhook_event(raw_body, headers)).to be_nil
      end
    end

    context 'with invalid signature' do
      before do
        allow(gateway).to receive(:verify_webhook_signature)
          .and_raise(Spree::PaymentMethod::WebhookSignatureError)
      end

      it 'raises WebhookSignatureError' do
        expect {
          gateway.parse_webhook_event(raw_body, headers)
        }.to raise_error(Spree::PaymentMethod::WebhookSignatureError)
      end
    end
  end
end
