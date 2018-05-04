require 'spec_helper'

describe Spree::Payment, type: :model do
  let(:order) { Spree::Order.create }
  let(:refund_reason) { create(:refund_reason) }

  let(:gateway) do
    gateway = Spree::Gateway::Bogus.new(active: true)
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
    ActiveMerchant::Billing::Response.new(true, '', {},       authorization: '123',
                                                              cvv_result: cvv_code,
                                                              avs_result: { code: avs_code })
  end

  let(:failed_response) do
    ActiveMerchant::Billing::Response.new(false, '', {}, {})
  end

  before do
    # Rails >= 5.0.3 returns new object for association so we ugly mock it
    allow(payment).to receive(:log_entries).and_return(payment.log_entries)

    # So it doesn't create log entries every time a processing method is called
    allow(payment.log_entries).to receive(:create!)
  end

  describe 'Constants' do
    it { expect(Spree::Payment::INVALID_STATES).to eq(%w(failed invalid)) }
  end

  describe 'scopes' do
    describe '.valid' do
      subject { Spree::Payment.valid }

      let!(:invalid_payment) do
        create(:payment, avs_response: 'Y', cvv_response_code: 'M', cvv_response_message: '', state: 'invalid')
      end

      let!(:failed_payment) do
        create(:payment, avs_response: 'Y', cvv_response_code: 'M', cvv_response_message: '', state: 'failed')
      end

      let!(:checkout_payment) do
        create(:payment, avs_response: 'A', cvv_response_code: 'M', cvv_response_message: '', state: 'checkout')
      end

      let!(:completed_payment) do
        create(:payment, avs_response: 'Y', cvv_response_code: 'N', cvv_response_message: '', state: 'completed')
      end

      it { is_expected.not_to include(invalid_payment) }
      it { is_expected.not_to include(failed_payment) }
      it { is_expected.to     include(checkout_payment) }
      it { is_expected.to     include(completed_payment) }
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

  context 'validations' do
    it 'returns useful error messages when source is invalid' do
      payment.source = Spree::CreditCard.new
      expect(payment).not_to be_valid
      cc_errors = payment.errors['Credit Card']
      expect(cc_errors).to include("Number can't be blank")
      expect(cc_errors).to include('Month is not a number')
      expect(cc_errors).to include('Year is not a number')
      expect(cc_errors).to include("Verification Value can't be blank")
    end
  end

  # Regression test for https://github.com/spree/spree/pull/2224
  context 'failure' do
    it 'transitions to failed from pending state' do
      payment.state = 'pending'
      payment.failure
      expect(payment.state).to eql('failed')
    end

    it 'transitions to failed from processing state' do
      payment.state = 'processing'
      payment.failure
      expect(payment.state).to eql('failed')
    end
  end

  context 'invalidate' do
    it 'transitions from checkout to invalid' do
      payment.state = 'checkout'
      payment.invalidate
      expect(payment.state).to eq('invalid')
    end
  end

  context 'processing' do
    describe '#process!' do
      it 'purchases if with auto_capture' do
        expect(payment.payment_method).to receive(:auto_capture?).and_return(true)
        payment.process!
        expect(payment).to be_completed
      end

      it 'authorizes without auto_capture' do
        expect(payment.payment_method).to receive(:auto_capture?).and_return(false)
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
        expect(payment.state).to eq('invalid')
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

      it 'logs the response' do
        payment.save!
        expect(payment.log_entries).to receive(:create!).with(details: anything)
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
          expect(payment.cvv_response_message).to eq(ActiveMerchant::Billing::CVVResult::MESSAGES[cvv_code])
        end

        it 'makes payment pending' do
          expect(payment).to receive(:pend!)
          payment.authorize!
        end
      end

      context 'if unsuccessful' do
        it 'marks payment as failed' do
          allow(gateway).to receive(:authorize).and_return(failed_response)
          expect(payment).to receive(:failure)
          expect(payment).not_to receive(:pend)
          expect do
            payment.authorize!
          end.to raise_error(Spree::Core::GatewayError)
        end
      end
    end

    describe '#purchase!' do
      it 'calls purchase on the gateway with the payment amount' do
        expect(gateway).to receive(:purchase).with(amount_in_cents, card, anything).and_return(success_response)
        payment.purchase!
      end

      it 'logs the response' do
        payment.save!
        expect(payment.log_entries).to receive(:create!).with(details: anything)
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
        before do
          allow(gateway).to receive(:purchase).and_return(failed_response)
          expect(payment).to receive(:failure)
          expect(payment).not_to receive(:pend)
        end

        it 'makes payment failed' do
          expect { payment.purchase! }.to raise_error(Spree::Core::GatewayError)
        end

        it 'does not log a capture event' do
          expect { payment.purchase! }.to raise_error(Spree::Core::GatewayError)
          expect(payment.capture_events.count).to eq(0)
        end
      end
    end

    describe '#capture!' do
      context 'when payment is pending' do
        before do
          payment.amount = 100
          payment.state = 'pending'
          payment.response_code = '12345'
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

          context 'for partial amount' do
            let(:original_amount) { payment.money.amount_in_cents }
            let(:capture_amount) { original_amount - 100 }

            before do
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
          it 'does not make payment complete' do
            allow(gateway).to receive_messages capture: failed_response
            expect(payment).to receive(:failure)
            expect(payment).not_to receive(:complete)
            expect { payment.capture! }.to raise_error(Spree::Core::GatewayError)
          end
        end
      end

      # Regression test for #2119
      context 'when payment is completed' do
        before do
          payment.state = 'completed'
        end

        it 'does nothing' do
          expect(payment).not_to receive(:complete)
          expect(payment.payment_method).not_to receive(:capture)
          expect(payment.log_entries).not_to receive(:create!)
          payment.capture!
        end
      end
    end

    describe '#void_transaction!' do
      before do
        payment.response_code = '123'
        payment.state = 'pending'
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

      it 'logs the response' do
        expect(payment.log_entries).to receive(:create!).with(details: anything)
        payment.void_transaction!
      end

      context 'if successful' do
        it 'updates the response_code with the authorization from the gateway' do
          # Change it to something different
          payment.response_code = 'abc'
          payment.void_transaction!
          expect(payment.response_code).to eq('12345')
        end
      end

      context 'if unsuccessful' do
        it 'does not void the payment' do
          allow(gateway).to receive_messages void: failed_response
          expect(payment).not_to receive(:void)
          expect { payment.void_transaction! }.to raise_error(Spree::Core::GatewayError)
        end
      end

      # Regression test for #2119
      context 'if payment is already voided' do
        before do
          payment.state = 'void'
        end

        it 'does not void the payment' do
          expect(payment.payment_method).not_to receive(:void)
          payment.void_transaction!
        end
      end
    end
  end

  context 'when already processing' do
    it 'returns nil without trying to process the source' do
      payment.state = 'processing'

      expect(payment.process!).to be_nil
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
    context 'raises no error if source is not specified' do
      before do
        payment.source = nil
        allow(payment.payment_method).to receive_messages(source_required?: false)
      end

      specify do
        expect { payment.process! }.not_to raise_error
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
    context 'captured payments' do
      it 'update order payment total' do
        payment = create(:payment, order: order, state: 'completed')
        expect(order.payment_total).to eq payment.amount
      end
    end

    context 'not completed payments' do
      it "doesn't update order payment total" do
        expect do
          Spree::Payment.create(amount: 100, order: order)
        end.not_to change(order, :payment_total)
      end

      it 'requires a payment method' do
        expect(Spree::Payment.create(amount: 100, order: order)).to have(1).error_on(:payment_method)
      end
    end

    context 'when the payment was completed but now void' do
      let(:payment) do
        Spree::Payment.create(
          amount: 100,
          order: order,
          state: 'completed'
        )
      end

      it 'updates order payment total' do
        payment.void
        expect(order.payment_total).to eq 0
      end
    end

    context 'completed orders' do
      before { allow(order).to receive_messages completed?: true }

      it 'updates payment_state and shipments' do
        expect(order.updater).to receive(:update_payment_state)
        expect(order.updater).to receive(:update_shipment_state)
        Spree::Payment.create(amount: 100, order: order, payment_method: gateway)
      end
    end

    context 'when profiles are supported' do
      before do
        allow(gateway).to receive_messages payment_profiles_supported?: true
        allow(payment.source).to receive_messages has_payment_profile?: false
      end

      context 'when there is an error connecting to the gateway' do
        it 'calls gateway_error' do
          message = double('gateway_error')
          connection_error = ActiveMerchant::ConnectionError.new(message, nil)
          expect(gateway).to receive(:create_profile).and_raise(connection_error)
          expect do
            Spree::Payment.create(
              amount: 100,
              order: order,
              source: card,
              payment_method: gateway
            )
          end.to raise_error(Spree::Core::GatewayError)
        end
      end

      context 'with multiple payment attempts' do
        let(:attributes) { attributes_for(:credit_card) }

        it 'does not try to create profiles on old failed payment attempts' do
          allow_any_instance_of(Spree::Payment).to receive(:payment_method) { gateway }

          order.payments.create!(
            source_attributes: attributes,
            payment_method: gateway,
            amount: 100
          )
          expect(gateway).to receive(:create_profile).exactly :once
          expect(order.payments.count).to eq(1)
          order.payments.create!(
            source_attributes: attributes,
            payment_method: gateway,
            amount: 100
          )
        end
      end

      context 'when successfully connecting to the gateway' do
        it 'creates a payment profile' do
          expect(payment.payment_method).to receive :create_profile
          Spree::Payment.create(
            amount: 100,
            order: order,
            source: card,
            payment_method: gateway
          )
        end
      end
    end

    context 'when profiles are not supported' do
      before { allow(gateway).to receive_messages payment_profiles_supported?: false }

      it 'does not create a payment profile' do
        expect(gateway).not_to receive :create_profile
        Spree::Payment.create(
          amount: 100,
          order: order,
          source: card,
          payment_method: gateway
        )
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
      payment = Spree::Payment.new(params)
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
      expect(payment.source.error_on(:number).size).to eq(1)
      expect(payment.source.error_on(:verification_value).size).to eq(1)
    end

    it 'does not build a new source when duplicating the model with source_attributes set' do
      payment = create(:payment)
      payment.source_attributes = params[:source_attributes]
      expect { payment.dup }.not_to change { payment.source }
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
      order.update_attributes(email: email)
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
        I18n.locale = :fr
        subject.amount = amount
      end

      after do
        I18n.locale = I18n.default_locale
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
    subject { payment }

    before do
      subject.state = state
    end

    context "when the state is 'checkout'" do
      let(:state) { 'checkout' }

      its(:editable?) { is_expected.to be(true) }
    end

    context "when the state is 'pending'" do
      let(:state) { 'pending' }

      its(:editable?) { is_expected.to be(true) }
    end

    %w[processing completed failed void invalid].each do |state|
      context "when the state is '#{state}'" do
        let(:state) { state }

        its(:editable?) { is_expected.to be(false) }
      end
    end
  end

  # Regression test for #4072 (kinda)
  # The need for this was discovered in the research for #4072
  context 'state changes' do
    it 'are logged to the database' do
      expect(payment.state_changes).to be_empty
      expect(payment.process!).to be true
      expect(payment.state_changes.count).to eq(2)
      changes = payment.state_changes.map { |change| { change.previous_state => change.next_state } }
      expect(changes).to match_array([
                                       { 'checkout' => 'processing' },
                                       { 'processing' => 'pending' }
                                     ])
    end
  end
end
