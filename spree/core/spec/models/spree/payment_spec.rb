require 'spec_helper'

describe Spree::Payment, type: :model do
  it_behaves_like 'lifecycle events'

  let(:store) { @default_store }
  let(:order) { create(:order, store: store, total: 200) }
  let(:refund_reason) { create(:refund_reason) }

  let(:gateway) do
    gateway = store.payment_methods.create!(type: 'Spree::Gateway::Bogus', active: true)
    allow(gateway).to receive_messages source_required: true
    gateway
  end

  let(:avs_code) { 'D' }
  let(:cvv_code) { 'M' }

  let(:card) { create :credit_card }

  let(:payment) do
    payment = Spree::Payment.new
    payment.source = card
    payment.order = order
    payment.payment_method = gateway
    payment.amount = 5
    payment
  end

  let(:amount_in_cents) { (payment.amount * 100).round }

  let!(:success_response) do
    Spree::PaymentResponse.new(true, '', {},       authorization: '123',
                                                   cvv_result: { code: cvv_code, message: nil },
                                                   avs_result: { code: avs_code })
  end

  let(:failed_response) do
    Spree::PaymentResponse.new(false, '', {}, {})
  end

  before do
    allow(payment).to receive(:payment_method_available_for_order).and_return(nil)
  end

  it_behaves_like 'metadata'

  describe 'Constants' do
    it { expect(Spree::Payment::INVALID_STATES).to eq(%w(failed invalid void)) }
  end

  describe 'Scopes' do
    describe '.valid' do
      subject { Spree::Payment.valid }

      let!(:invalid_payment) do
        create(:payment, avs_response: 'Y', cvv_response_code: 'M', cvv_response_message: '', status: 'invalid')
      end

      let!(:failed_payment) do
        create(:payment, avs_response: 'Y', cvv_response_code: 'M', cvv_response_message: '', status: 'failed')
      end

      let!(:checkout_payment) do
        create(:payment, avs_response: 'A', cvv_response_code: 'M', cvv_response_message: '', status: 'checkout')
      end

      let!(:completed_payment) do
        create(:payment, avs_response: 'Y', cvv_response_code: 'N', cvv_response_message: '', status: 'completed')
      end

      it { is_expected.not_to include(invalid_payment) }
      it { is_expected.not_to include(failed_payment) }
      it { is_expected.to     include(checkout_payment) }
      it { is_expected.to     include(completed_payment) }
    end
  end

  describe 'after_initialize :set_amount' do
    subject { payment.amount }

    context 'when associated with an order' do
      let(:order) { create(:order, payment_total: 10, total: 45) }
      let(:payment) { described_class.new(order: order) }

      it 'sets the amount to the order total minus the payment total' do
        expect(subject).to eq(order.total - order.payment_total)
      end

      context 'when the amount is already set' do
        let(:payment) { described_class.new(order: order, amount: 10) }

        it 'does not set the amount' do
          expect(subject).to eq(10)
        end
      end
    end

    context 'when not associated with an order' do
      let(:payment) { described_class.new }

      it 'does not set the amount' do
        expect(subject).to eq(0)
      end
    end
  end

  context '.risky' do
    let!(:payment_1) { create(:payment, avs_response: 'Y', cvv_response_code: 'M', cvv_response_message: 'Match') }
    let!(:payment_2) { create(:payment, avs_response: 'Y', cvv_response_code: 'M', cvv_response_message: '') }
    let!(:payment_3) { create(:payment, avs_response: 'A', cvv_response_code: 'M', cvv_response_message: 'Match') }
    let!(:payment_4) { create(:payment, avs_response: 'Y', cvv_response_code: 'N', cvv_response_message: 'No Match') }

    it 'does not return successful responses' do
      expect(subject.class.risky.to_a).to match_array([payment_3, payment_4])
    end
  end

  context '#captured_amount' do
    context 'calculates based on capture events' do
      it 'with 0 capture events' do
        expect(payment.captured_amount).to eq(0)
      end

      it 'with some capture events' do
        payment.save
        payment.capture_events.create!(amount: 2.0)
        payment.capture_events.create!(amount: 3.0)
        expect(payment.captured_amount).to eq(5)
      end
    end
  end

  context '#uncaptured_amount' do
    context 'calculates based on capture events' do
      it 'with 0 capture events' do
        expect(payment.uncaptured_amount).to eq(5.0)
      end

      it 'with some capture events' do
        payment.save
        payment.capture_events.create!(amount: 2.0)
        payment.capture_events.create!(amount: 3.0)
        expect(payment.uncaptured_amount).to eq(0)
      end
    end
  end

  describe 'Validations' do
    context 'when payment source is not required' do
      it 'do not validate source presence' do
        allow_any_instance_of(Spree::PaymentMethod).to receive(:source_required?).and_return(false)

        payment.source = nil
        expect(payment).to be_valid
      end
    end

    context 'with payment source required' do
      it 'validate source presence' do
        payment.source = nil
        expect(payment).not_to be_valid
      end

      context 'when skip_source_requirement is set to true' do
        it 'does not validate source presence' do
          payment.skip_source_requirement = true
          expect(payment).to be_valid
        end
      end
    end

    it 'returns useful error messages when source is invalid' do
      payment.source = Spree::CreditCard.new
      expect(payment).not_to be_valid
      cc_errors = payment.errors['Credit Card']
      expect(cc_errors).to include("Number can't be blank")
      expect(cc_errors).to include('Month is not a number')
      expect(cc_errors).to include('Year is not a number')
      expect(cc_errors).to include("Verification Value can't be blank")
    end

    describe 'amount validation' do
      subject { payment.valid? }

      let(:payment) { build(:payment, amount: payment_amount, order: order) }

      context 'with an associated order' do
        let(:order) { create(:order, total: 100) }

        context 'when the amount is greater than the max amount' do
          let(:payment_amount) { 101 }

          it 'is invalid' do
            subject

            expect(payment).not_to be_valid
            expect(payment.errors.full_messages).to include('Amount is greater than the allowed maximum amount of 100.0')
          end
        end

        context 'when the amount is less than the max amount' do
          let(:payment_amount) { 99 }

          it { is_expected.to be(true) }
        end
      end
    end
  end

  describe 'Callbacks' do
    # events: true — the order learns about payment changes through events
    # now, not an after_save callback, and they are disabled by default in
    # the test environment.
    describe 'keeping the order in step', events: true do
      let(:payment) { create(:payment, order: order, status: 'completed') }

      context 'when destroying completed payment' do
        it 'updates the order' do
          expect { payment.destroy }.to change { order.reload.payment_total }.by(-payment.amount)
        end
      end

      context 'when voiding a payment' do
        it 'updates the order' do
          expect { payment.void! }.to change { order.reload.payment_total }.by(-payment.amount)
        end
      end
    end

    describe '#create_payment_profile' do
      context 'when payment method supports profiles' do
        context 'when source is a credit card' do
          let(:source) { create(:credit_card) }
          let(:payment) { create(:payment, source: source) }

          it 'creates a payment profile' do
            expect { payment.create_payment_profile }.to change { source.gateway_customer_profile_id }.from(nil).to(/BGS-/)
          end
        end

        context 'when source is not a credit card' do
          let(:user) { create(:user) }
          let(:order) { create(:order, customer: user, total: 100) }
          let(:gateway) { create(:custom_payment_method) }
          let(:source) { create(:payment_source, customer: user, payment_method: gateway) }
          let(:payment) { create(:custom_payment, source: source, amount: 100, payment_method: gateway) }

          it 'creates a payment profile' do
            expect { payment.create_payment_profile }.to change { source.gateway_customer_profile_id }.from(nil).to("CUSTOMER-#{user.id}")
          end
        end
      end
    end
  end

  # Regression test for https://github.com/spree/spree/pull/2224
  context 'failure' do
    it 'transitions to failed from pending state' do
      payment.status = 'pending'
      payment.failure
      expect(payment.status).to eql('failed')
    end

    it 'transitions to failed from processing state' do
      payment.status = 'processing'
      payment.failure
      expect(payment.status).to eql('failed')
    end
  end

  context 'invalidate' do
    it 'moves from checkout to invalid' do
      payment.status = 'checkout'
      payment.invalidate!
      expect(payment.status).to eq('invalid')
    end
  end

  context 'processing' do
    describe '#process!' do
      it 'purchases when the method charges at checkout' do
        payment.payment_method.capture_method = 'checkout'
        payment.process!
        expect(payment).to be_completed
      end

      it 'authorizes when the method charges later' do
        payment.payment_method.capture_method = 'on_dispatch'
        payment.process!
        expect(payment).to be_pending
      end

      it "makes the state 'processing'" do
        expect(payment).to receive(:started_processing!)
        payment.process!
      end

      it 'invalidates if payment method doesnt support source' do
        expect(payment.payment_method).to receive(:supports?).with(payment.source).and_return(false)
        expect { payment.process! }.to raise_error(Spree::Core::GatewayError)
        expect(payment.status).to eq('invalid')
      end

      # Regression test for #4598
      it 'allows payments with a gateway_customer_profile_id' do
        allow(payment.source).to receive_messages gateway_customer_profile_id: 'customer_1'
        expect(payment.payment_method).to receive(:supports?).with(payment.source).and_return(false)
        expect(payment).to receive(:started_processing!)
        payment.process!
      end

      # Another regression test for #4598
      it 'allows payments with a gateway_payment_profile_id' do
        allow(payment.source).to receive_messages gateway_payment_profile_id: 'customer_1'
        expect(payment.payment_method).to receive(:supports?).with(payment.source).and_return(false)
        expect(payment).to receive(:started_processing!)
        payment.process!
      end
    end

    describe '#authorize!' do
      it 'calls authorize on the gateway with the payment amount' do
        expect(payment.payment_method).to receive(:authorize).with(amount_in_cents,
                                                                   card,
                                                                   anything).and_return(success_response)
        payment.authorize!
      end

      it 'calls authorize on the gateway with the currency code' do
        allow(payment).to receive_messages currency: 'GBP'
        expect(payment.payment_method).to receive(:authorize).with(amount_in_cents,
                                                                   card,
                                                                   hash_including(currency: 'GBP')).and_return(success_response)
        payment.authorize!
      end

      context 'if successful' do
        before do
          expect(payment.payment_method).to receive(:authorize).with(amount_in_cents,
                                                                     card,
                                                                     anything).and_return(success_response)
        end

        it 'stores the response_code, avs_response and cvv_response fields' do
          payment.authorize!
          expect(payment.response_code).to eq('123')
          expect(payment.avs_response).to eq(avs_code)
          expect(payment.cvv_response_code).to eq(cvv_code)
          expect(payment.cvv_response_message).to be_nil
        end

        it 'makes payment pending' do
          expect(payment).to receive(:pend!)
          payment.authorize!
        end
      end

      context 'if unsuccessful' do
        context 'when response is returned from gateway' do
          it 'marks payment as failed' do
            allow(gateway).to receive(:authorize).and_return(failed_response)
            expect do
              payment.authorize!
            end.to raise_error(Spree::Core::GatewayError)
            expect(payment.reload).to be_failed
          end
        end

        context 'when there is an error connecting to the gateway' do
          let(:connection_error_message) { 'gateway_error' }
          let(:connection_error) { Spree::PaymentConnectionError.new(connection_error_message) }

          before { allow(gateway).to receive(:authorize).and_raise(connection_error) }

          it 'raises Spree::Core::GatewayError and marks payment as failed' do
            expect(payment).to receive(:failure!)
            expect(payment).not_to receive(:pend)
            expect { payment.authorize! }.to raise_error(Spree::Core::GatewayError)
          end
        end
      end
    end

    describe 'gateway instrumentation' do
      def capture_gateway_notifications
        events = []
        subscriber = ActiveSupport::Notifications.subscribe('gateway.spree_payments') do |*, payload|
          events << payload
        end
        yield
        events
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      it 'instruments the purchase gateway call as gateway.spree_payments' do
        allow(gateway).to receive(:purchase).and_return(success_response)

        notifications = capture_gateway_notifications { payment.purchase! }

        expect(notifications.sole).to include(action: 'purchase', payment_method_type: 'Spree::Gateway::Bogus')
      end

      it 'instruments the capture gateway call' do
        payment.status = 'pending'
        payment.response_code = "BGS-#{SecureRandom.hex(6)}"
        allow(gateway).to receive(:capture).and_return(success_response)

        notifications = capture_gateway_notifications { payment.capture! }

        expect(notifications.sole).to include(action: 'capture', payment_method_type: 'Spree::Gateway::Bogus')
      end
    end

    describe '#purchase!' do
      it 'calls purchase on the gateway with the payment amount' do
        expect(gateway).to receive(:purchase).with(amount_in_cents, card, anything).and_return(success_response)
        payment.purchase!
      end

      context 'if successful' do
        before do
          expect(payment.payment_method).to receive(:purchase).with(amount_in_cents,
                                                                    card,
                                                                    anything).and_return(success_response)
        end

        it 'stores the response_code and avs_response' do
          payment.purchase!
          expect(payment.response_code).to eq('123')
          expect(payment.avs_response).to eq(avs_code)
        end

        it 'makes payment complete' do
          expect(payment).to receive(:complete!)
          payment.purchase!
        end

        it 'logs a capture event' do
          payment.purchase!
          expect(payment.capture_events.count).to eq(1)
          expect(payment.capture_events.first.amount).to eq(payment.amount)
        end

        it 'sets the uncaptured amount to 0' do
          payment.purchase!
          expect(payment.uncaptured_amount).to eq(0)
        end
      end

      context 'if unsuccessful' do
        context 'when response is returned from gateway' do
          before do
            allow(gateway).to receive(:purchase).and_return(failed_response)
          end

          it 'makes payment failed' do
            expect { payment.purchase! }.to raise_error(Spree::Core::GatewayError)
            expect(payment.reload).to be_failed
          end

          it 'does not log a capture event' do
            expect { payment.purchase! }.to raise_error(Spree::Core::GatewayError)
            expect(payment.capture_events.count).to eq(0)
          end
        end

        context 'when there is an error connecting to the gateway' do
          let(:connection_error_message) { 'gateway_error' }
          let(:connection_error) { Spree::PaymentConnectionError.new(connection_error_message) }

          before { allow(gateway).to receive(:purchase).and_raise(connection_error) }

          it 'raises Spree::Core::GatewayError and marks payment as failed' do
            expect(payment).to receive(:failure!)
            expect(payment).not_to receive(:pend)
            expect { payment.purchase! }.to raise_error(Spree::Core::GatewayError)
          end
        end
      end
    end

    describe '#confirm!' do
      subject(:confirm!) { payment.confirm! }

      before do
        gateway.update!(capture_method: capture_method)
      end

      context 'for automatically captured payments' do
        let(:capture_method) { 'checkout' }

        it 'makes the payment complete' do
          confirm!
          expect(payment.reload).to be_completed
        end

        it 'logs a capture event' do
          confirm!

          expect(payment.reload.capture_events.count).to eq(1)
          expect(payment.capture_events.first.amount).to eq(payment.amount)
        end

        context 'when payment is already completed' do
          before do
            payment.complete!
            payment.capture_events.create!(amount: payment.amount)
          end

          it 'keeps the payment completed' do
            confirm!
            expect(payment.reload).to be_completed
          end

          it 'does not log a duplicated capture event' do
            expect { confirm! }.not_to change(Spree::PaymentCaptureEvent, :count)
            expect(payment.reload.capture_events.count).to eq(1)
          end
        end
      end

      context 'for manually captured payments' do
        let(:capture_method) { 'manual' }

        it 'makes the payment pending' do
          confirm!
          expect(payment.reload).to be_pending
        end

        context 'when payment is already pending' do
          before do
            payment.pend!
          end

          it 'keeps the payment pending' do
            confirm!
            expect(payment.reload).to be_pending
          end
        end
      end

      # The caller reporting actual gateway state overrides the method's
      # capture timing in both directions.
      context 'when the funds are captured on a manual-capture method' do
        let(:capture_method) { 'manual' }

        it 'completes the payment with a capture event' do
          payment.confirm!(captured: true)

          expect(payment.reload).to be_completed
          expect(payment.capture_events.count).to eq(1)
        end
      end

      context 'when the funds are not captured on a checkout-capture method' do
        let(:capture_method) { 'checkout' }

        it 'pends the payment' do
          payment.confirm!(captured: false)

          expect(payment.reload).to be_pending
          expect(payment.capture_events).to be_empty
        end
      end
    end

    describe 'risk codes from the source (before_create)' do
      before do
        allow(gateway).to receive(:risk_codes_for).with(card).and_return(
          avs_response: 'A', cvv_response_code: 'N'
        )
      end

      it 'asks the payment method for risk codes at creation' do
        payment.save!

        expect(payment.avs_response).to eq('A')
        expect(payment.cvv_response_code).to eq('N')
      end

      it 'never overwrites codes the gateway response already set' do
        payment.avs_response = 'Y'
        payment.cvv_response_code = 'M'
        payment.save!

        expect(payment.avs_response).to eq('Y')
        expect(payment.cvv_response_code).to eq('M')
      end

      it 'does not ask again on later saves' do
        payment.save!
        expect(gateway).not_to receive(:risk_codes_for)

        payment.update!(amount: 4)
      end
    end

    describe '#capture!' do
      context 'when payment is pending' do
        before do
          payment.amount = 100
          payment.status = 'pending'
          payment.response_code = "BGS-#{SecureRandom.hex(6)}"
        end

        context 'if successful' do
          context 'for entire amount' do
            before do
              expect(payment.payment_method).to receive(:capture).with(payment.display_amount.amount_in_cents, payment.response_code, anything).and_return(success_response)
            end

            it 'makes payment complete' do
              expect(payment).to receive(:complete!)
              payment.capture!
            end

            it 'logs capture events' do
              payment.capture!
              expect(payment.capture_events.count).to eq(1)
              expect(payment.capture_events.first.amount).to eq(payment.amount)
            end
          end

          it 'records the capture under the owner row lock' do
            expect(payment.payment_method).to receive(:capture).and_return(success_response)
            expect(payment.owner).to receive(:with_lock).and_call_original

            payment.capture!
          end

          it 'records nothing when another caller already completed the payment' do
            expect(payment.payment_method).to receive(:capture).and_return(success_response)
            # Simulates the concurrent winner committing between the gateway
            # call and the bookkeeping lock.
            allow(Spree::Payment).to receive_message_chain(:where, :exists?).and_return(true)

            expect { payment.capture! }.not_to change { payment.capture_events.count }
          end

          context 'for partial amount' do
            let(:original_amount) { payment.money.amount_in_cents }
            let(:capture_amount) { original_amount - 100 }

            before do
              allow_any_instance_of(Spree::Payment).to receive(:payment_method_available_for_order).and_return(nil)
              expect(payment.payment_method).to receive(:capture).with(capture_amount, payment.response_code, anything).and_return(success_response)
            end

            it 'makes payment complete & create pending payment for remaining amount' do
              expect(payment).to receive(:complete!)
              payment.capture!(capture_amount)
              order = payment.order
              payments = order.payments

              expect(payments.size).to eq 2
              expect(payments.pending.first.amount).to eq 1
              # Payment stays processing for spec because of receive(:complete!) stub.
              expect(payments.processing.first.amount).to eq(capture_amount / 100)
              expect(payments.processing.first.source).to eq(payments.pending.first.source)
            end

            it 'logs capture events' do
              payment.capture!(capture_amount)
              expect(payment.capture_events.count).to eq(1)
              expect(payment.capture_events.first.amount).to eq(capture_amount / 100)
            end
          end
        end

        context 'if unsuccessful' do
          context 'when response is returned from gateway' do
            it 'does not make payment complete' do
              allow(gateway).to receive_messages capture: failed_response
              expect { payment.capture! }.to raise_error(Spree::Core::GatewayError)
              expect(payment.reload).to be_failed
              expect(payment).not_to be_completed
            end
          end

          context 'when there is an error connecting to the gateway' do
            let(:connection_error_message) { 'gateway_error' }
            let(:connection_error) { Spree::PaymentConnectionError.new(connection_error_message) }

            before { allow(gateway).to receive(:capture).and_raise(connection_error) }

            it 'raises Spree::Core::GatewayError and marks payment as failed' do
              expect(payment).to receive(:failure!)
              expect(payment).not_to receive(:pend)
              expect { payment.capture! }.to raise_error(Spree::Core::GatewayError)
            end
          end
        end
      end

      # Regression test for #2119
      context 'when payment is completed' do
        before do
          payment.status = 'completed'
        end

        it 'does nothing' do
          expect(payment.payment_method).not_to receive(:capture)
          payment.capture!
        end
      end
    end

    describe '#void_transaction!' do
      before do
        payment.response_code = '123'
        payment.status = 'pending'
      end

      context 'when profiles are supported' do
        it "calls payment_gateway.void with the payment's response_code" do
          allow(gateway).to receive_messages payment_profiles_supported?: true
          expect(gateway).to receive(:void).with('123', card, anything).and_return(success_response)
          payment.void_transaction!
        end
      end

      context 'when profiles are not supported' do
        it "calls payment_gateway.void with the payment's response_code" do
          allow(gateway).to receive_messages payment_profiles_supported?: false
          expect(gateway).to receive(:void).with('123', anything).and_return(success_response)
          payment.void_transaction!
        end
      end

      context 'if successful' do
        it 'updates the response_code with the authorization from the gateway' do
          # Change it to something different
          payment.response_code = 'abc'
          payment.void_transaction!
          expect(payment.response_code).to start_with('void-BGS-')
        end
      end

      context 'if unsuccessful' do
        context 'when response is returned from gateway' do
          it 'does not void the payment' do
            allow(gateway).to receive_messages void: failed_response
            expect { payment.void_transaction! }.to raise_error(Spree::Core::GatewayError)
            expect(payment).not_to be_void
          end
        end

        context 'when there is an error connecting to the gateway' do
          let(:connection_error_message) { 'gateway_error' }
          let(:connection_error) { Spree::PaymentConnectionError.new(connection_error_message) }

          before { allow(gateway).to receive(:void).and_raise(connection_error) }

          it 'raises Spree::Core::GatewayError and marks payment as failed' do
            expect(payment).to receive(:failure!)
            expect(payment).not_to receive(:pend)
            expect { payment.void_transaction! }.to raise_error(Spree::Core::GatewayError)
          end
        end
      end

      # Regression test for #2119
      context 'if payment is already voided' do
        before do
          payment.status = 'void'
        end

        it 'does not void the payment' do
          expect(payment.payment_method).not_to receive(:void)
          payment.void_transaction!
        end
      end

      context 'if response_code is blank' do
        before do
          payment.response_code = nil
          payment.status = 'pending'
        end

        it 'voids the payment without calling the gateway' do
          expect(payment.payment_method).not_to receive(:void)
          payment.void_transaction!
          expect(payment.status).to eq('void')
        end
      end
    end
  end

  context 'when already processing' do
    it 'is a no-op success without trying to process the source' do
      payment.status = 'processing'

      expect(payment.process!).to be(true)
    end
  end

  context 'with source required' do
    context 'raises an error if no source is specified' do
      before do
        payment.source = nil
      end

      specify do
        expect { payment.process! }.to raise_error(Spree::Core::GatewayError, Spree.t(:payment_processing_failed))
      end
    end
  end

  context 'with source optional' do
    context 'when payment method does not require source' do
      let(:check_payment_method) { create(:check_payment_method, store: order.store, capture_method: 'manual') }

      before do
        payment.source = nil
        payment.payment_method = check_payment_method
      end

      it 'processes successfully and transitions to pending' do
        expect { payment.process! }.not_to raise_error
        expect(payment.status).to eq('pending')
      end

      context 'with auto capture' do
        let(:check_payment_method) { create(:check_payment_method, store: order.store, capture_method: 'checkout') }

        it 'processes successfully and transitions to completed' do
          expect { payment.process! }.not_to raise_error
          expect(payment.status).to eq('completed')
        end
      end
    end
  end

  describe '#credit_allowed' do
    # Regression test for #4403 & #4407
    it 'is the difference between offsets total and payment amount' do
      payment.amount = 100
      allow(payment).to receive(:offsets_total).and_return(0)
      expect(payment.credit_allowed).to eq(100)
      allow(payment).to receive(:offsets_total).and_return(-80)
      expect(payment.credit_allowed).to eq(20)
    end
  end

  describe '#can_credit?' do
    it 'is true if credit_allowed > 0' do
      allow(payment).to receive(:credit_allowed).and_return(100)
      expect(payment.can_credit?).to be true
    end

    it 'is false if credit_allowed is 0' do
      allow(payment).to receive(:credit_allowed).and_return(0)
      expect(payment.can_credit?).to be false
    end
  end

  describe '#save' do
    context 'captured payments', events: true do
      it 'update order payment total' do
        payment = create(:payment, order: order, status: 'completed')
        expect(order.reload.payment_total).to eq payment.amount
      end
    end

    context 'not completed payments' do
      it "doesn't update order payment total" do
        expect do
          Spree::Payment.create(amount: 100, order: order)
        end.not_to change(order, :payment_total)
      end

      it 'requires a payment method' do
        expect(Spree::Payment.create(amount: 100, order: order).errors).not_to be_empty
        expect(Spree::Payment.create(amount: 100, order: order).errors.messages[:payment_method]).to be_present
      end
    end

    context 'when the payment was completed but now void' do
      let(:payment) { create(:payment, order: order, amount: 100, status: 'completed') }

      it 'updates order payment total' do
        payment.void!
        expect(order.reload.payment_total).to eq 0
      end
    end

    context 'completed orders' do
      before { allow(order).to receive_messages completed?: true }

      it 'recomputes totals and statuses' do
        expect { Spree::Payment.create(amount: 100, order: order, payment_method: gateway, source: card) }
          .to change { order.reload.updated_at }
      end
    end

    context 'when profiles are supported' do
      before do
        allow(gateway).to receive_messages payment_profiles_supported?: true
        allow(payment.source).to receive_messages has_payment_profile?: false
      end

      it 'never creates the profile from the save itself' do
        expect(gateway).not_to receive(:create_profile)

        Spree::Payment.create(
          amount: 100,
          order: order,
          source: card,
          payment_method: gateway
        )
      end

      context 'when there is an error connecting to the gateway' do
        it 'calls gateway_error' do
          connection_error = Spree::PaymentConnectionError.new('gateway_error')
          expect(gateway).to receive(:create_profile).and_raise(connection_error)

          saved_payment = Spree::Payment.create(
            amount: 100,
            order: order,
            source: card,
            payment_method: gateway
          )

          expect { saved_payment.create_payment_profile }.to raise_error(Spree::Core::GatewayError)
        end
      end

      context 'with an invalidated payment attempt' do
        it 'does not try to create a profile' do
          saved_payment = Spree::Payment.create!(
            amount: 100,
            order: order,
            source: card,
            payment_method: gateway
          )
          saved_payment.invalidate!

          expect(gateway).not_to receive(:create_profile)
          saved_payment.create_payment_profile
        end
      end

      context 'when successfully connecting to the gateway' do
        it 'creates a payment profile' do
          expect(gateway).to receive :create_profile

          Spree::Payment.create(
            amount: 100,
            order: order,
            source: card,
            payment_method: gateway
          ).create_payment_profile
        end
      end
    end
  end

  describe '#build_source' do
    let(:params) do
      {
        amount: 100,
        payment_method: gateway,
        source_attributes: {
          expiry: '01 / 99',
          number: '1234567890123',
          verification_value: '123',
          name: 'Spree Commerce'
        }
      }
    end

    it "builds the payment's source" do
      payment = Spree::Payment.new(params.merge(order: order))
      expect(payment).to be_valid
      expect(payment.source).not_to be_nil
    end

    it 'assigns user and gateway to payment source' do
      order = create(:order)
      source = order.payments.new(params).source

      expect(source.user_id).to eq order.user_id
      expect(source.payment_method_id).to eq gateway.id
    end

    it 'errors when payment source not valid' do
      params = { amount: 100, payment_method: gateway,
                 source_attributes: { expiry: '1 / 12' } }

      payment = Spree::Payment.new(params)
      expect(payment).not_to be_valid
      expect(payment.source).not_to be_nil
      expect(payment.source.errors.messages[:name]).to be_present
      expect(payment.source.errors).not_to be_empty
      expect(payment.source.errors.messages[:verification_value]).to be_present
    end

    it 'does not build a new source when duplicating the model with source_attributes set' do
      payment = create(:payment)
      payment.source_attributes = params[:source_attributes]
      expect { payment.dup }.not_to change { payment.source }
    end

    context 'existing card' do
      let!(:credit_card) { create(:credit_card, number: '4111111111111112', customer: order.user, payment_method: gateway, gateway_customer_profile_id: 'BGS-1234567890') }

      let(:params) do
        {
          amount: 100,
          order: order,
          payment_method: gateway,
          source_attributes: {
            id: credit_card.id
          }
        }
      end

      it 'assigns the existing card' do
        payment = Spree::Payment.new(params)
        expect(payment.source).to eq(credit_card)
        expect(payment.source.gateway_customer_profile_id).to eq('BGS-1234567890')
      end
    end
  end

  describe '#currency' do
    before { allow(order).to receive(:currency).and_return('ABC') }

    it 'returns the order currency' do
      expect(payment.currency).to eq('ABC')
    end
  end

  describe '#display_amount' do
    it 'returns a Spree::Money for this amount' do
      expect(payment.display_amount).to eq(Spree::Money.new(payment.amount))
    end
  end

  # Regression test for #2216
  describe '#gateway_options' do
    before { allow(order).to receive_messages(last_ip_address: '192.168.1.1') }

    it 'contains an IP' do
      expect(payment.gateway_options[:ip]).to eq(order.last_ip_address)
    end

    it 'contains the email address from a persisted order' do
      # Sets the payment's order to a different Ruby object entirely
      payment.order = Spree::Order.find(payment.order_id)
      email = 'foo@example.com'
      order.update(email: email)
      expect(payment.gateway_options[:email]).to eq(email)
    end
  end

  describe '#amount=' do
    before do
      subject.amount = amount
    end

    context 'when the amount is a string' do
      context 'amount is a decimal' do
        let(:amount) { '2.99' }

        it '#amount' do
          expect(subject.amount).to eql(BigDecimal('2.99'))
        end
      end

      context 'amount is an integer' do
        let(:amount) { '2' }

        it '#amount' do
          expect(subject.amount).to eql(BigDecimal('2.0'))
        end
      end

      context 'amount contains a dollar sign' do
        let(:amount) { '$2.99' }

        it '#amount' do
          expect(subject.amount).to eql(BigDecimal('2.99'))
        end
      end

      context 'amount contains a comma' do
        let(:amount) { '$2,999.99' }

        it '#amount' do
          expect(subject.amount).to eql(BigDecimal('2999.99'))
        end
      end

      context 'amount contains a negative sign' do
        let(:amount) { '-2.99' }

        it '#amount' do
          expect(subject.amount).to eql(BigDecimal('-2.99'))
        end
      end

      context 'amount is invalid' do
        let(:amount) { 'invalid' }

        # this is a strange default for ActiveRecord

        it '#amount' do
          expect(subject.amount).to eql(BigDecimal('0'))
        end
      end

      context 'amount is an empty string' do
        let(:amount) { '' }

        it '#amount' do
          expect(subject.amount).to be_nil
        end
      end
    end

    context 'when the amount is a number' do
      let(:amount) { 1.55 }

      it '#amount' do
        expect(subject.amount).to eql(BigDecimal('1.55'))
      end
    end

    context 'when the locale uses a coma as a decimal separator' do
      before do
        I18n.backend.store_translations(:fr, number: { currency: { format: { delimiter: ' ', separator: ',' } } })
        allow(I18n).to receive(:locale).and_return(:fr)
        allow(I18n.config).to receive(:locale).and_return(:fr)

        subject.amount = amount
      end

      context 'amount is a decimal' do
        let(:amount) { '2,99' }

        it '#amount' do
          expect(subject.amount).to eql(BigDecimal('2.99'))
        end
      end

      context 'amount contains a $ sign' do
        let(:amount) { '2,99 $' }

        it '#amount' do
          expect(subject.amount).to eql(BigDecimal('2.99'))
        end
      end

      context 'amount is a number' do
        let(:amount) { 2.99 }

        it '#amount' do
          expect(subject.amount).to eql(BigDecimal('2.99'))
        end
      end

      context 'amount contains a negative sign' do
        let(:amount) { '-2,99 $' }

        it '#amount' do
          expect(subject.amount).to eql(BigDecimal('-2.99'))
        end
      end

      context 'amount uses a dot as a decimal separator' do
        let(:amount) { '2.99' }

        it '#amount' do
          expect(subject.amount).to eql(BigDecimal('2.99'))
        end
      end
    end
  end

  describe 'is_avs_risky?' do
    it 'returns false if avs_response included in NON_RISKY_AVS_CODES' do
      ('A'..'Z').reject { |x| subject.class::RISKY_AVS_CODES.include?(x) }.to_a.each do |char|
        payment.update_attribute(:avs_response, char)
        expect(payment.is_avs_risky?).to eq false
      end
    end

    it 'returns false if avs_response.blank?' do
      payment.update_attribute(:avs_response, nil)
      expect(payment.is_avs_risky?).to eq false
      payment.update_attribute(:avs_response, '')
      expect(payment.is_avs_risky?).to eq false
    end

    it 'returns true if avs_response in RISKY_AVS_CODES' do
      # should use avs_response_code helper
      ('A'..'Z').reject { |x| subject.class::NON_RISKY_AVS_CODES.include?(x) }.to_a.each do |char|
        payment.update_attribute(:avs_response, char)
        expect(payment.is_avs_risky?).to eq true
      end
    end
  end

  describe 'is_cvv_risky?' do
    it "returns false if cvv_response_code == 'M'" do
      payment.update_attribute(:cvv_response_code, 'M')
      expect(payment.is_cvv_risky?).to eq(false)
    end

    it 'returns false if cvv_response_code == nil' do
      payment.update_attribute(:cvv_response_code, nil)
      expect(payment.is_cvv_risky?).to eq(false)
    end

    it "returns false if cvv_response_message == ''" do
      payment.update_attribute(:cvv_response_message, '')
      expect(payment.is_cvv_risky?).to eq(false)
    end

    it 'returns true if cvv_response_code == [A-Z], omitting D' do
      # should use cvv_response_code helper
      (%w{N P S U} << '').each do |char|
        payment.update_attribute(:cvv_response_code, char)
        expect(payment.is_cvv_risky?).to eq(true)
      end
    end
  end

  describe '#editable?' do
    before { payment.status = state }

    context "when the state is 'checkout'" do
      let(:state) { 'checkout' }

      it { expect(payment.editable?).to eq(true) }
    end

    context "when the state is 'pending'" do
      let(:state) { 'pending' }

      it { expect(payment.editable?).to eq(true) }
    end

    %w[processing completed failed void invalid].each do |state|
      context "when the state is '#{state}'" do
        let(:state) { state }

        it { expect(payment.editable?).to eq(false) }
      end
    end
  end

  describe '#source' do
    context 'with source required enabled' do
      let(:payment) { create(:payment, payment_method: payment_method, source: card, status: 'completed') }
      let(:card) { create(:credit_card) }
      let(:payment_method) { card.payment_method }

      before do
        allow(payment_method).to receive_messages source_required: true
      end

      it { expect(payment_method.source_required?).to eq(true) }
      it { expect(payment.source).to eq(card) }

      context 'when credit card is removed' do
        before do
          card.destroy!
          payment.reload
        end

        it { expect(payment.source).to eq(card) }
        it { expect(payment.source.deleted_at).not_to be_nil }
      end
    end

    context 'with source required disabled' do
      let(:payment) { create(:check_payment) }

      it { expect(payment.source).to be_nil }
    end
  end

  describe '#display_source_name' do
    let(:payment_method) { create(:credit_card_payment_method) }
    let(:payment) { build(:payment, payment_method: payment_method) }

    before do
      allow(payment).to receive(:source).and_return(source)
    end

    subject { payment.display_source_name }

    context 'for source with display_name' do
      let(:source) { double('Payment Source', class: double('Payment Source Class', display_name: 'Display 554')) }

      it 'returns the display name of the source class' do
        expect(subject).to eq('Display 554')
      end
    end

    context 'for source without display_name' do
      let(:source) { double('Payment Source', class: double('Payment Source Class', name: 'MyPaymentMethod')) }

      it 'returns the display name of the source class' do
        expect(subject).to eq('My Payment Method')
      end
    end
  end

  describe '#gateway_dashboard_payment_url' do
    it 'returns nil' do
      expect(payment.gateway_dashboard_payment_url).to be_nil
    end

    let(:payment) { create(:payment, payment_method: gateway, transaction_id: '123') }

    context 'when implemented' do
      before do
        expect(gateway).to receive(:gateway_dashboard_payment_url).with(payment).and_return("https://dashboard.stripe.com/payments/#{payment.transaction_id}")
      end

      it 'returns the url' do
        expect(payment.gateway_dashboard_payment_url).to eq("https://dashboard.stripe.com/payments/#{payment.transaction_id}")
      end
    end
  end

  describe '#add_gateway_processing_error' do
    subject { payment.add_gateway_processing_error('Insufficient balance on payment') }

    # A payment has no store of its own and reaches one through what it
    # settles. Resolving through `order` alone left a cart-owned payment
    # filing its error against whichever store the request named — the
    # default one in a job.
    describe 'the store its custom fields are defined in' do
      let(:other_store) { create(:store) }

      it 'is the order it settles' do
        order_payment = build(:payment, order: create(:order, store: other_store))

        expect(order_payment.send(:custom_field_definition_store)).to eq(other_store)
      end

      it 'is the cart it settles while checkout is still open' do
        cart_payment = build(:payment, order: nil, cart: create(:cart, store: other_store))

        expect(cart_payment.send(:custom_field_definition_store)).to eq(other_store)
      end
    end

    it 'adds a gateway processing error' do
      subject
      expect(payment.get_custom_field('gateway.processing_errors').value).to eq([{ message: 'Insufficient balance on payment' }].to_json)
    end

    context 'when the custom_field already exists' do
      before do
        payment.set_custom_field('gateway.processing_errors', [{ message: 'Gateway processing error' }].to_json)
      end

      it 'adds a gateway processing error' do
        subject

        expect(payment.get_custom_field('gateway.processing_errors').value).to eq(
          [
            { message: 'Gateway processing error' },
            { message: 'Insufficient balance on payment' }
          ].to_json
        )
      end
    end
  end

  describe '#has_invalid_state?' do
    let(:payment) { create(:payment, status: state) }
    subject(:has_invalid_state?) { payment.has_invalid_state? }

    context 'when the state is invalid' do
      let(:state) { Spree::Payment::INVALID_STATES.first }

      it { is_expected.to be_truthy }
    end

    context 'when the state is valid' do
      let(:state) { 'completed' }

      it { is_expected.to be_falsey }
    end
  end

  describe '#gateway_processing_error_messages' do
    before do
      payment.add_gateway_processing_error('Gateway processing error')
      payment.add_gateway_processing_error('Another gateway processing error')
    end

    it 'returns the gateway processing error messages' do
      expect(payment.gateway_processing_error_messages).to eq(['Gateway processing error', 'Another gateway processing error'])
    end
  end

  describe 'events', events: true do
    describe 'completed state transition' do
      it 'publishes payment.completed event' do
        payment.started_processing!
        expect(payment).to receive(:publish_event).with('payment.completed')
        allow(payment).to receive(:publish_event).with(anything)

        payment.complete!
      end
    end

    describe 'voided state transition' do
      before do
        payment.started_processing!
        payment.pend!
      end

      it 'publishes payment.voided event' do
        expect(payment).to receive(:publish_event).with('payment.voided')
        allow(payment).to receive(:publish_event).with(anything)

        payment.void!
      end
    end
  end
end
