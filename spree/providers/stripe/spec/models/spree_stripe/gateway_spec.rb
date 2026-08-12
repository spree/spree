require 'spec_helper'

RSpec.describe SpreeStripe::Gateway do
  let(:store) { @default_store }
  let(:gateway) { create(:stripe_gateway, store: store) }
  let(:amount) { 100 }

  describe '#payment_intent_accepted?' do
    subject { gateway.payment_intent_accepted?(stripe_payment_intent) }

    let(:stripe_payment_intent) do
      Stripe::StripeObject.construct_from(
        id: 'pi_123',
        status: payment_intent_status,
        capture_method: capture_method,
        payment_method: {
          type: payment_method_type
        }
      )
    end
    let(:capture_method) { 'automatic' }

    context 'for a card payment method' do
      let(:payment_method_type) { 'card' }

      context 'when the payment intent is succeeded' do
        let(:payment_intent_status) { 'succeeded' }

        it { is_expected.to be(true) }
      end

      context 'when the payment intent is processing' do
        let(:payment_intent_status) { 'processing' }

        it { is_expected.to be(false) }
      end

      context 'when the payment intent status is requires_action' do
        let(:payment_intent_status) { 'requires_action' }

        it { is_expected.to be(false) }
      end

      context 'when the payment intent is failed' do
        let(:payment_intent_status) { 'failed' }

        it { is_expected.to be(false) }
      end

      context 'when the payment intent status is requires_capture' do
        let(:payment_intent_status) { 'requires_capture' }

        context 'when capture_method is manual' do
          let(:capture_method) { 'manual' }

          it { is_expected.to be(true) }
        end

        context 'when capture_method is automatic' do
          let(:capture_method) { 'automatic' }

          it { is_expected.to be(false) }
        end
      end
    end

    context 'for a sepa debit payment method' do
      let(:payment_method_type) { 'sepa_debit' }

      context 'when the payment intent is succeeded' do
        let(:payment_intent_status) { 'succeeded' }

        it { is_expected.to be(true) }
      end

      context 'when the payment intent is processing' do
        let(:payment_intent_status) { 'processing' }

        it { is_expected.to be(true) }
      end

      context 'when the payment intent status is requires_action' do
        let(:payment_intent_status) { 'requires_action' }

        it { is_expected.to be(false) }
      end

      context 'when the payment intent is failed' do
        let(:payment_intent_status) { 'failed' }

        it { is_expected.to be(false) }
      end
    end

    context 'for a bank transfer payment method' do
      let(:payment_method_type) { 'customer_balance' }

      context 'when the payment intent is succeeded' do
        let(:payment_intent_status) { 'succeeded' }

        it { is_expected.to be(true) }
      end

      context 'when the payment intent is processing' do
        let(:payment_intent_status) { 'processing' }

        it { is_expected.to be(false) }
      end

      context 'when the payment intent status is requires_action' do
        let(:payment_intent_status) { 'requires_action' }

        it { is_expected.to be(true) }
      end

      context 'when the payment intent is failed' do
        let(:payment_intent_status) { 'failed' }

        it { is_expected.to be(false) }
      end
    end

    context 'for a us bank account payment method' do
      let(:payment_method_type) { 'us_bank_account' }

      context 'when the payment intent is succeeded' do
        let(:payment_intent_status) { 'succeeded' }

        it { is_expected.to be(true) }
      end

      context 'when the payment intent is processing' do
        let(:payment_intent_status) { 'processing' }

        it { is_expected.to be(true) }
      end

      context 'when the payment intent status is requires_action' do
        let(:payment_intent_status) { 'requires_action' }

        it { is_expected.to be(true) }
      end

      context 'when the payment intent is failed' do
        let(:payment_intent_status) { 'failed' }

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#payment_intent_charge_not_required?' do
    subject { gateway.payment_intent_charge_not_required?(stripe_payment_intent) }

    let(:stripe_payment_intent) do
      Stripe::StripeObject.construct_from(
        id: 'pi_123',
        status: 'succeeded',
        payment_method: stripe_payment_method
      )
    end

    let(:stripe_payment_method) do
      { type: payment_method_type }
    end

    context 'for a card payment method' do
      let(:payment_method_type) { 'card' }

      it { is_expected.to be(false) }
    end

    context 'for a customer_balance payment method' do
      let(:payment_method_type) { 'customer_balance' }

      it { is_expected.to be(true) }
    end

    context 'for a us_bank_account payment method' do
      let(:payment_method_type) { 'us_bank_account' }

      it { is_expected.to be(true) }
    end

    context 'when the payment method is not expanded' do
      let(:stripe_payment_method) { 'pm_1234567890' }

      it { is_expected.to be(false) }
    end

    context 'when the payment method type is not provided' do
      let(:stripe_payment_method) { nil }

      it { is_expected.to be(false) }
    end
  end

  describe '#payment_intent_manual_capture?' do
    subject { gateway.payment_intent_manual_capture?(stripe_pi) }

    let(:stripe_pi) { Stripe::StripeObject.construct_from(id: 'pi_x', capture_method: capture_method) }

    context 'when capture_method is manual' do
      let(:capture_method) { 'manual' }

      it { is_expected.to be(true) }
    end

    context 'when capture_method is automatic' do
      let(:capture_method) { 'automatic' }

      it { is_expected.to be(false) }
    end

    context 'when capture_method is missing' do
      let(:stripe_pi) { Stripe::StripeObject.construct_from(id: 'pi_x') }

      it { is_expected.to be(false) }
    end
  end

  describe '#payment_intent_requires_capture?' do
    subject { gateway.payment_intent_requires_capture?(stripe_pi) }

    let(:stripe_pi) { Stripe::StripeObject.construct_from(id: 'pi_x', status: status) }

    context 'when status is requires_capture' do
      let(:status) { 'requires_capture' }

      it { is_expected.to be(true) }
    end

    context 'when status is succeeded' do
      let(:status) { 'succeeded' }

      it { is_expected.to be(false) }
    end
  end

  describe '#webhook_url' do
    subject { gateway.webhook_url }

    it 'returns the core payment webhook url' do
      expect(subject).to eq("#{store.url_or_custom_domain}/api/v3/webhooks/payments/#{gateway.prefixed_id}")
    end
  end

  describe 'creating the payment intent' do
    subject { gateway.send(:create_payment_intent, amount, order) }

    let(:order) { create(:order_with_line_items, store: store) }

    let(:payment_intent_id) { 'pi_3QXmfC2ESifGlJez0qSmz8Vf' }

    it 'creates a payment intent' do
      VCR.use_cassette('create_payment_intent') do
        expect(subject.success?).to be(true)
        expect(subject.authorization).to eq(payment_intent_id)
      end
    end

    context 'when shipping address is invalid' do
      let(:order) do
        build(
          :order_with_line_items,
          ship_address: build(:address, address1: nil),
          store: store
        )
      end

      let(:payment_intent_id) { 'pi_3QY1a32ESifGlJez0k9YRZnS' }

      it 'creates the payment intent without shipping address' do
        VCR.use_cassette('create_payment_intent_invalid_address') do
          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)
          expect(subject.params['shipping']).to be_nil
        end
      end

      # Validating the live record would leave its errors populated for the
      # caller, so the check runs against a duplicate.
      it 'leaves the order address errors untouched' do
        VCR.use_cassette('create_payment_intent_invalid_address') do
          subject

          expect(order.ship_address.errors).to be_empty
        end
      end
    end

    context 'when auto_capture is false on the gateway' do
      before { gateway.update!(auto_capture: false) }

      it 'asks Stripe for manual capture' do
        VCR.use_cassette('create_payment_intent_manual_capture') do
          expect(subject.success?).to be(true)
          expect(subject.params['capture_method']).to eq('manual')
          expect(subject.params['status']).to eq('requires_payment_method')
        end
      end
    end

    context 'when auto_capture is true on the gateway' do
      before { gateway.update!(auto_capture: true) }

      it 'leaves the capture method to Stripe' do
        VCR.use_cassette('create_payment_intent') do
          expect(subject.success?).to be(true)
          expect(subject.params['capture_method']).to eq('automatic')
        end
      end
    end
  end

  describe 'updating the payment intent' do
    subject { gateway.send(:update_payment_intent, payment_intent_id, amount, order, payment_method_id) }

    let!(:gateway_customer) { create(:gateway_customer, customer: order.customer, payment_method: gateway, profile_id: customer_id) }
    let(:order) { create(:order_with_line_items, store: store) }

    let(:amount) { 4000 }
    let(:payment_method_id) { nil }

    let(:customer_id) { 'cus_RQdclxFVLH4oau' }
    let(:payment_intent_id) { 'pi_3QY2qD2ESifGlJez0VuzXjwK' }

    context 'when the amount is different' do
      let(:amount) { 6000 }

      it 'updates the payment intent with a new amount' do
        VCR.use_cassette('update_payment_intent_new_amount') do
          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)
          expect(subject.params['amount']).to eq(6000)
        end
      end
    end

    context 'when the shipping address is different' do
      let(:address) do
        create(
          :address,
          firstname: 'Jane',
          lastname: 'Zoe',
          address1: '100 California Street',
          address2: nil,
          city: 'San Francisco',
          zipcode: '94111',
          state: california_state,
          country: usa_country
        )
      end

      let(:usa_country) { Spree::Country.by_iso('US') || create(:country_us) }
      let(:california_state) { usa_country.states.find_by(abbr: 'CA') || create(:state, name: 'California', abbr: 'CA', country: usa_country) }

      before do
        order.update!(shipping_address: address)
      end

      it 'updates the payment intent with a new address' do
        VCR.use_cassette('update_payment_intent_new_address') do
          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)

          expect(subject.params['shipping']['name']).to eq('Jane Zoe')
          expect(subject.params['shipping']['address']).to eq(
            'city' => 'San Francisco',
            'country' => 'US',
            'line1' => '100 California Street',
            'line2' => nil,
            'postal_code' => '94111',
            'state' => 'CA'
          )
        end
      end
    end

    context 'when giving a payment method' do
      let(:payment_method_id) { 'pm_1QXmPJ2ESifGlJezC2py6ZqS' }

      it 'updates the payment intent with a payment method' do
        VCR.use_cassette('update_payment_intent_payment_method') do
          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)
          expect(subject.params['payment_method']).to eq(payment_method_id)
        end
      end
    end
  end

  describe '#cancel' do
    subject { gateway.cancel(payment_intent_id, payment) }

    let!(:refund_reason) { Spree::RefundReason.first || create(:default_refund_reason) }

    context 'when payment is completed' do
      let!(:order) { create(:order, store: store, total: 10, customer: create(:customer)) }
      let!(:gateway_customer) { create(:gateway_customer, customer: order.customer, payment_method: gateway) }

      let!(:payment) { create(:payment, state: 'completed', order: order, payment_method: gateway, amount: 10.0, response_code: payment_intent_id) }
      let!(:refund) { create(:refund, payment: payment, amount: 2.0) }

      let(:payment_intent_id) { 'pi_3QXmL12ESifGlJez0v0B8tUn' }
      let(:refund_id) { 're_3QXmL12ESifGlJez0GcOBHng' }

      it 'creates a refund with credit_allowed_amount' do
        VCR.use_cassette('create_refund') do
          expect { subject }.to change(Spree::Refund, :count).by(1)

          expect(payment.refunds.last.amount).to eq(8.0)

          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)

          expect(subject.params['id']).to eq(refund_id)
          expect(subject.params['status']).to eq('succeeded')
          expect(subject.params['payment_intent']).to eq(payment_intent_id)
          expect(subject.params['object']).to eq('refund')
          expect(subject.params['amount']).to eq(800)
        end
      end

      context 'if amount to refund is zero' do
        let!(:refund) { create(:refund, payment: payment, amount: payment.amount) }

        it 'does not create refund' do
          expect { subject }.not_to change(Spree::Refund, :count)

          expect(subject.success?).to be true
          expect(subject.authorization).to eq(payment_intent_id)
        end
      end
    end

    context 'when payment is not completed' do
      let!(:payment) { create(:payment, response_code: payment_intent_id) }

      let(:payment_intent_id) { 'pi_3QY1o72ESifGlJez06ZbKHjy' }

      it 'cancels the payment intent' do
        VCR.use_cassette('cancel_payment_intent') do
          expect { subject }.not_to change(Spree::Refund, :count)

          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)
          expect(subject.params['status']).to eq('canceled')
        end
      end
    end
  end

  describe '#credit' do
    subject { gateway.credit(amount_in_cents, nil, payment_intent_id, {}) }

    let(:amount_in_cents) { 800 }
    let(:payment_intent_id) { 'pi_3QXmL12ESifGlJez0v0B8tUn' }

    let(:refund_id) { 're_3QXmL12ESifGlJez0GcOBHng' }

    it 'refunds some of the payment amount' do
      VCR.use_cassette('create_refund') do
        expect(subject.success?).to be(true)
        expect(subject.authorization).to eq(refund_id)

        expect(subject.params['id']).to eq(refund_id)
        expect(subject.params['status']).to eq('succeeded')
        expect(subject.params['payment_intent']).to eq(payment_intent_id)
        expect(subject.params['object']).to eq('refund')
        expect(subject.params['amount']).to eq(800)
      end
    end
  end

  describe '#void' do
    subject(:void) { gateway.void(payment_intent_id, nil, nil) }

    let(:payment_intent_id) { 'pi_3QY1o72ESifGlJez06ZbKHjy' }

    it 'voids the payment intent' do
      VCR.use_cassette('cancel_payment_intent') do
        expect(void.success?).to be(true)
        expect(void.authorization).to eq(payment_intent_id)
      end
    end

    context 'when no response code is provided' do
      let(:payment_intent_id) { nil }

      it 'returns a failure' do
        expect(void.success?).to be(false)
        expect(void.message).to eq('Response code is blank')
      end
    end
  end

  describe '#capture' do
    subject { gateway.capture(amount_in_cents, payment_intent_id) }

    let(:amount_in_cents) { 1000 }

    # A manual-capture intent is bootstrapped on Stripe so it sits in
    # `requires_capture` before `gateway.capture(...)` runs. The cassette records
    # both, which is faithful to a real auth-then-capture flow.
    context 'when the payment intent is in requires_capture state' do
      let(:payment_intent_id) do
        Stripe::PaymentIntent.create(
          {
            amount: amount_in_cents,
            currency: 'usd',
            payment_method: 'pm_card_visa',
            confirm: true,
            capture_method: 'manual',
            automatic_payment_methods: { enabled: true, allow_redirects: 'never' }
          },
          { api_key: gateway.preferred_secret_key }
        ).id
      end

      it 'captures the payment intent through Stripe' do
        VCR.use_cassette('capture_payment_intent_requires_capture') do
          expect(subject.success?).to be(true)
          expect(subject.authorization).to eq(payment_intent_id)
          expect(subject.params['status']).to eq('succeeded')
          expect(subject.params['amount_received']).to eq(amount_in_cents)
        end
      end
    end

    context 'when the payment intent is already succeeded (idempotent capture)' do
      let(:payment_intent_id) do
        Stripe::PaymentIntent.create(
          {
            amount: amount_in_cents,
            currency: 'usd',
            payment_method: 'pm_card_visa',
            confirm: true,
            automatic_payment_methods: { enabled: true, allow_redirects: 'never' }
          },
          { api_key: gateway.preferred_secret_key }
        ).id
      end

      it 'returns the existing payment intent without re-capturing' do
        VCR.use_cassette('capture_payment_intent_already_succeeded') do
          expect(subject.success?).to be(true)
          expect(subject.params['status']).to eq('succeeded')
        end
      end
    end

    context 'when the payment intent is in an unsupported state' do
      let(:payment_intent_id) do
        Stripe::PaymentIntent.create(
          {
            amount: amount_in_cents,
            currency: 'usd',
            automatic_payment_methods: { enabled: true, allow_redirects: 'never' }
          },
          { api_key: gateway.preferred_secret_key }
        ).id
      end

      it 'raises a GatewayError' do
        VCR.use_cassette('capture_payment_intent_unsupported_state') do
          expect { subject }.to raise_error(Spree::Core::GatewayError, /Payment intent status is/)
        end
      end
    end
  end

  describe '#purchase' do
    subject { gateway.purchase(amount_in_cents, credit_card, { order_id: order_id }) }

    let(:amount_in_cents) { 1000 }
    let(:order_id) { "#{order.number}-#{payment.number}" }

    let!(:order) { create(:order_with_line_items, store: store, number: 'R111098765', customer: create(:customer)) }
    let!(:gateway_customer) { create(:gateway_customer, customer: order.customer, payment_method: gateway) }
    let!(:credit_card) { create(:credit_card, gateway_payment_profile_id: payment_method_id, payment_method: gateway) }
    let!(:payment) do
      create(:payment, number: 'ABC1DEF2', amount: order.total, payment_method: gateway, order: order,
                       source: credit_card, response_code: payment_intent_id)
    end

    let(:payment_method_id) { 'pm_1QXmPJ2ESifGlJezC2py6ZqS' }
    let(:payment_intent_id) { 'pi_3QY1y22ESifGlJez12haN8ah' }

    it 'reads back the already confirmed payment intent' do
      VCR.use_cassette('create_payment_intent_with_payment_method') do
        expect(subject.success?).to be true

        expect(subject.authorization).to eq(payment_intent_id)
        expect(subject.params['status']).to eq('succeeded')
        expect(subject.params['amount']).to eq(amount_in_cents)
      end
    end

    context 'when the order id is malformed' do
      let(:order_id) { 'missing' }

      it 'returns failure' do
        expect(subject.success?).to be(false)
        expect(subject.message).to eq('Payment number is invalid')
      end
    end

    context 'when the payment has no payment intent' do
      let(:payment_intent_id) { nil }

      it 'returns failure' do
        expect(subject.success?).to be(false)
        expect(subject.message).to eq('Payment is missing a payment intent')
      end
    end
  end

  describe '#fetch_or_create_customer' do
    subject { gateway.fetch_or_create_customer(order: order, customer: customer) }

    let(:customer) { create(:customer) }
    let(:order) { nil }

    context 'when a gateway customer already exists' do
      let!(:gateway_customer) { create(:gateway_customer, customer: customer, payment_method: gateway) }

      it 'returns the existing record without calling Stripe' do
        expect { expect(subject).to eq(gateway_customer) }.not_to change(Spree::GatewayCustomer, :count)
      end
    end

    context 'when neither an order nor a customer is given' do
      let(:customer) { nil }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#create_customer' do
    subject { gateway.create_customer(order: order, customer: customer) }

    let(:order) { create(:order_with_line_items, store: store, customer: customer, bill_address: bill_address, email: 'test@example.com') }
    let(:customer) { create(:customer, email: 'test@example.com', first_name: 'Jane', last_name: 'Moe', bill_address: customer_bill_address) }

    let(:bill_address) do
      create(
        :address,
        city: 'San Francisco',
        address1: '100 California Street',
        address2: 'Apt 1',
        zipcode: '94111',
        state: california_state,
        country: usa_country,
        firstname: 'John',
        lastname: 'Doe',
        phone: '1234567890'
      )
    end

    let(:customer_bill_address) do
      create(
        :address,
        city: 'New York',
        address1: '100 Main Street',
        address2: 'Apt 2',
        zipcode: '10001',
        state: new_york_state,
        country: usa_country
      )
    end

    let(:usa_country) { Spree::Country.by_iso('US') || create(:country_us) }
    let(:california_state) { usa_country.states.find_by(abbr: 'CA') || create(:state, name: 'California', abbr: 'CA', country: usa_country) }
    let(:new_york_state) { usa_country.states.find_by(abbr: 'NY') || create(:state, name: 'New York', abbr: 'NY', country: usa_country) }

    let(:gateway_customer) { Spree::GatewayCustomer.for_provider(SpreeStripe::Gateway).last }

    it 'creates a new Stripe customer and gateway customer record' do
      VCR.use_cassette('create_customer') do
        expect { subject }.to change(Spree::GatewayCustomer, :count).by(1)

        expect(subject).to eq(gateway_customer)
        expect(subject.customer).to eq(customer)
        expect(subject.profile_id).to eq(gateway_customer.profile_id)
        expect(subject.payment_method).to eq(gateway)
        expect(subject.persisted?).to be(true)
      end
    end

    it 'builds the Stripe payload from the order' do
      expect(SpreeStripe::CustomerPresenter).to receive(:new).with(
        name: order.name, email: order.email, address: bill_address
      ).and_call_original

      VCR.use_cassette('create_customer') { subject }
    end

    context 'when customer is nil' do
      let(:customer) { nil }
      let(:order) { create(:order_with_line_items, store: store, customer: nil, bill_address: bill_address, email: 'test@example.com') }

      it 'creates a customer but does not save the gateway customer record' do
        VCR.use_cassette('create_customer') do
          expect { subject }.not_to change(Spree::GatewayCustomer, :count)

          expect(subject).to be_new_record
          expect(subject.customer).to be_nil
          expect(subject.profile_id).to be_present
          expect(subject.payment_method).to eq(gateway)
        end
      end
    end

    context 'when only a customer is provided' do
      subject { gateway.create_customer(customer: customer) }

      it 'creates a customer using only the customer information' do
        VCR.use_cassette('create_customer_based_on_user') do
          expect { subject }.to change(Spree::GatewayCustomer, :count).by(1)

          expect(subject).to eq(gateway_customer)
          expect(subject.customer).to eq(customer)
          expect(subject.persisted?).to be(true)
        end
      end

      it 'builds the Stripe payload from the customer' do
        expect(SpreeStripe::CustomerPresenter).to receive(:new).with(
          name: customer.full_name, email: customer.email, address: customer_bill_address
        ).and_call_original

        VCR.use_cassette('create_customer_based_on_user') { subject }
      end
    end
  end

  describe '#update_customer' do
    subject { gateway.update_customer(order: order, customer: customer) }

    let(:order) { create(:order_with_line_items, store: store, customer: customer, bill_address: bill_address) }
    let(:customer) { create(:customer, email: 'test-updated@example.com', first_name: 'Jane', last_name: 'Moe', bill_address: customer_bill_address) }

    let(:bill_address) do
      create(
        :address,
        city: 'San Francisco',
        address1: '200 California Street',
        address2: 'Apt 11',
        zipcode: '94112',
        state: california_state,
        country: usa_country,
        firstname: 'John',
        lastname: 'Doe'
      )
    end

    let(:customer_bill_address) do
      create(
        :address,
        city: 'New York',
        address1: '200 Main Street',
        address2: 'Apt 22',
        zipcode: '10002',
        state: new_york_state,
        country: usa_country
      )
    end

    let(:usa_country) { Spree::Country.by_iso('US') || create(:country_us) }
    let(:california_state) { usa_country.states.find_by(abbr: 'CA') || create(:state, name: 'California', abbr: 'CA', country: usa_country) }
    let(:new_york_state) { usa_country.states.find_by(abbr: 'NY') || create(:state, name: 'New York', abbr: 'NY', country: usa_country) }

    let!(:gateway_customer) { create(:gateway_customer, customer: customer, profile_id: customer_id, payment_method: gateway) }
    let(:customer_id) { 'cus_SeIsxI1TG3dGJv' }

    it 'updates the existing Stripe customer' do
      VCR.use_cassette('update_customer') do
        expect { subject }.not_to change(Spree::GatewayCustomer, :count)

        expect(subject.id).to eq(customer_id)
      end
    end

    context 'when customer is nil' do
      let(:customer) { nil }
      let(:gateway_customer) { nil }
      let(:order) { create(:order_with_line_items, store: store, customer: nil, bill_address: bill_address) }

      it 'does nothing' do
        expect(subject).to be_nil
      end
    end

    context 'when the gateway customer does not exist' do
      let(:gateway_customer) { nil }

      it 'does nothing' do
        expect(subject).to be_nil
      end
    end

    context 'when only a customer is provided' do
      subject { gateway.update_customer(customer: customer) }

      it 'updates the customer using only the customer information' do
        VCR.use_cassette('update_customer_based_on_user') do
          expect { subject }.not_to change(Spree::GatewayCustomer, :count)

          expect(subject.id).to eq(customer_id)
        end
      end
    end
  end

  describe '#risk_codes_for' do
    subject { gateway.risk_codes_for(source) }

    context 'with a credit card carrying Stripe checks' do
      let(:source) do
        build(:credit_card, metadata: {
                checks: {
                  address_line1_check: 'pass',
                  address_postal_code_check: 'fail',
                  cvc_check: 'pass'
                }
              })
      end

      it 'translates them to AVS and CVV response codes' do
        expect(subject).to eq(avs_response: 'A', cvv_response_code: 'M')
      end
    end

    context 'with a credit card without checks' do
      let(:source) { build(:credit_card) }

      it { is_expected.to be_nil }
    end

    context 'with a non-card source' do
      let(:source) { SpreeStripe::PaymentSources::Klarna.new }

      it { is_expected.to be_nil }
    end
  end

  describe 'being a provider' do
    let(:provider_methods) { %i[authorize purchase capture void credit] }

    it 'implements provider methods without delegating back to itself' do
      provider_methods.each do |method|
        expect(gateway).to respond_to method
        expect { gateway.send(method) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#setup_session_supported?' do
    it 'returns true' do
      expect(gateway.setup_session_supported?).to be(true)
    end
  end

  describe '#payment_setup_session_class' do
    it 'returns the Stripe STI subclass' do
      expect(gateway.payment_setup_session_class).to eq(Spree::PaymentSetupSessions::Stripe)
    end
  end

  describe '#create_payment_setup_session' do
    subject { gateway.create_payment_setup_session(customer: customer) }

    let(:customer) { create(:customer) }

    context 'when the customer has no saved Stripe customer' do
      it 'creates the gateway customer and a Stripe payment setup session' do
        VCR.use_cassette('create_payment_setup_session') do
          expect { subject }.to change(gateway.gateway_customers, :count).by(1).
            and change(Spree::PaymentSetupSession, :count).by(1)

          expect(subject).to be_a(Spree::PaymentSetupSessions::Stripe)
          expect(subject).to be_persisted
          expect(subject.customer).to eq(customer)
          expect(subject.payment_method).to eq(gateway)
          expect(subject.status).to eq('pending')
          expect(subject.external_id).to start_with('seti_')
          expect(subject.external_client_secret).to include('_secret_')
          expect(subject.external_data['customer_id']).to start_with('cus_')
          expect(subject.external_data['ephemeral_key_secret']).to start_with('ek_test_')
        end
      end
    end

    context 'when the customer has a saved Stripe customer' do
      let(:saved_customer_id) { 'cus_USE66TMAPae0UB' }
      let!(:gateway_customer) { create(:gateway_customer, customer: customer, profile_id: saved_customer_id, payment_method: gateway) }

      it 'reuses the saved customer for the setup session' do
        VCR.use_cassette('create_payment_setup_session_existing_customer') do
          expect { subject }.to_not change(gateway.gateway_customers, :count)
          expect(subject).to be_persisted
          expect(subject.external_data['customer_id']).to eq(saved_customer_id)
        end
      end
    end

    context 'when external_data is provided' do
      subject { gateway.create_payment_setup_session(customer: customer, external_data: { 'foo' => 'bar' }) }

      it 'merges the provided data into external_data' do
        VCR.use_cassette('create_payment_setup_session') do
          expect(subject.external_data).to include('foo' => 'bar')
          expect(subject.external_data).to include('customer_id', 'ephemeral_key_secret')
        end
      end
    end
  end

  describe '#complete_payment_setup_session' do
    subject { gateway.complete_payment_setup_session(setup_session: setup_session) }

    let(:customer) { create(:customer) }
    let!(:gateway_customer) { create(:gateway_customer, customer: customer, payment_method: gateway, profile_id: 'cus_test') }
    let(:setup_session) do
      create(:stripe_payment_setup_session,
             customer: customer,
             payment_method: gateway,
             external_id: 'seti_test_xyz',
             external_client_secret: 'seti_test_xyz_secret',
             external_data: { 'customer_id' => 'cus_test' })
    end

    let(:stripe_payment_method) do
      Stripe::StripeObject.construct_from(
        id: 'pm_card_visa',
        type: 'card',
        billing_details: { name: 'Jane Doe' },
        card: {
          brand: 'visa',
          last4: '4242',
          exp_month: 12,
          exp_year: 2030,
          fingerprint: 'FZqjhq46SWprIY8i',
          checks: nil,
          wallet: nil
        }
      )
    end

    context 'when the SetupIntent succeeded' do
      let(:stripe_setup_intent) do
        Stripe::StripeObject.construct_from(
          id: 'seti_test_xyz',
          status: 'succeeded',
          payment_method: stripe_payment_method
        )
      end

      before do
        allow(gateway).to receive(:retrieve_setup_intent).with('seti_test_xyz').and_return(stripe_setup_intent)
      end

      it 'creates a payment source and completes the session' do
        expect { subject }.to change(Spree::CreditCard, :count).by(1)

        setup_session.reload
        expect(setup_session.status).to eq('completed')
        expect(setup_session.payment_source).to be_a(Spree::CreditCard)
        expect(setup_session.payment_source.gateway_payment_profile_id).to eq('pm_card_visa')
        expect(setup_session.payment_source.customer).to eq(customer)
      end
    end

    context 'when the SetupIntent has not succeeded' do
      let(:stripe_setup_intent) do
        Stripe::StripeObject.construct_from(
          id: 'seti_test_xyz',
          status: 'requires_payment_method',
          payment_method: nil
        )
      end

      before do
        allow(gateway).to receive(:retrieve_setup_intent).with('seti_test_xyz').and_return(stripe_setup_intent)
      end

      it 'fails the session without creating a source' do
        expect(SpreeStripe::CreateSource).not_to receive(:new)
        expect { subject }.not_to change(Spree::CreditCard, :count)

        setup_session.reload
        expect(setup_session.status).to eq('failed')
        expect(setup_session.payment_source).to be_nil
      end
    end
  end

  describe '#parse_webhook_event' do
    subject(:result) { gateway.parse_webhook_event(raw_body, headers) }

    let(:order) { create(:order_with_line_items, store: store) }
    let(:raw_body) { '{"id": "evt_test"}' }
    let(:headers) { { 'HTTP_STRIPE_SIGNATURE' => 'sig_test' } }

    let!(:payment_session) do
      create(:stripe_payment_session, owner: order, payment_method: gateway, external_id: 'pi_webhook_999')
    end

    let(:stripe_event) do
      Stripe::StripeObject.construct_from(
        type: 'payment_intent.amount_capturable_updated',
        data: { object: { id: 'pi_webhook_999' } }
      )
    end

    context 'when the signature is valid' do
      before do
        allow(Stripe::Webhook).to receive(:construct_event).and_return(stripe_event)
      end

      let(:gateway) { create(:stripe_gateway, :with_webhook_signing_secret, store: store) }

      it 'verifies the signature against the gateway preference' do
        expect(Stripe::Webhook).to receive(:construct_event).with(raw_body, 'sig_test', 'whsec_test_1234567890')

        expect(result[:action]).to eq(:authorized)
        expect(result[:payment_session]).to eq(payment_session)
      end
    end

    context 'when the signature does not verify against any known secret' do
      let(:gateway) { create(:stripe_gateway, :with_webhook_signing_secret, store: store) }

      before do
        allow(Stripe::Webhook).to receive(:construct_event).and_raise(Stripe::SignatureVerificationError.new('bad', 'sig_test'))
      end

      it 'raises a WebhookSignatureError' do
        expect { result }.to raise_error(Spree::PaymentMethod::WebhookSignatureError)
      end
    end
  end

  describe 'webhook endpoint registration' do
    it 'enqueues the registration job on create' do
      expect { gateway }.to have_enqueued_job(SpreeStripe::CreateWebhookEndpointJob)
    end

    context 'when the signing secret is already stored' do
      it 'does not enqueue the registration job' do
        expect do
          create(:stripe_gateway, :with_webhook_signing_secret, store: store)
        end.not_to have_enqueued_job(SpreeStripe::CreateWebhookEndpointJob)
      end
    end
  end
end
