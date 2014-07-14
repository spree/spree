require 'spec_helper'

describe Spree::Refund do

  describe '.perform!' do
    let(:payment_amount) { 100.0 }
    let(:authorization) { "TEST12" }
    let(:payment) { create(:payment) }
    let(:refund_reason) { create(:refund_reason) }

    subject { Spree::Refund.perform!(payment, refund_reason, payment_amount) }

    context "processing is successful" do
      let(:response) {
        ActiveMerchant::Billing::Response.new(true, "", {}, { authorization: authorization })
      }

      before { Spree::Refund.should_receive(:process!) { response } }

      it 'should create a refund' do
        expect{ subject }.to change{ Spree::Refund.count }.by(1)
      end

      it 'return the newly created refund' do
        expect(subject).to be_a(Spree::Refund)
      end

      it 'should save the returned authorization value' do
        expect(subject.transaction_id).to eq authorization
      end

      it 'should save the passed amount as the refund amount' do
        expect(subject.amount).to eq payment_amount
      end

      it 'should create a log entry' do
        expect(subject.log_entries).to be_present
      end
    end

    context "processing fails" do
      before do
        Spree::Refund.should_receive(:process!)
          .and_raise(Spree::Core::GatewayError)
      end

      it 'should raise error and not create a refund' do
        expect do
          expect { subject }.to raise_error(Spree::Core::GatewayError)
        end.to_not change{ Spree::Refund.count }
      end
    end
  end

  describe '.process!' do
    let(:payment) { create(:payment) }
    let(:credit_cents) { 10_00 }
    let(:response) {
      ActiveMerchant::Billing::Response.new(response_success, response_message, {}, {})
    }
    let(:response_message) { "response message" }
    let(:response_success) { true }
    let(:support_payment_profiles) { true }

    before do
      payment.payment_method.stub(:payment_profiles_supported?) { support_payment_profiles }
    end

    subject { Spree::Refund.process!(payment, credit_cents) }

    context 'without payment profiles supported' do
      let(:support_payment_profiles) { false }

      before do
        payment.payment_method
          .should_receive(:credit)
          .with(credit_cents, payment.transaction_id, {})
          .and_return(response)
      end

      it 'should supply the payment source' do
        subject
      end
    end

    context 'with payment profiles supported' do
      let(:support_payment_profiles) { true }

      before do
        payment.payment_method
          .should_receive(:credit)
          .with(credit_cents, payment.source, payment.transaction_id, {})
          .and_return(response)
      end

      it 'should supply the payment source' do
        subject
      end
    end

    context 'with successful response' do
      let(:response_success) { true }

      before do
        payment.payment_method
          .should_receive(:credit)
          .with(credit_cents, payment.source, payment.transaction_id, {})
          .and_return(response)
      end

      it 'returns the response' do
        expect(subject).to eq response
      end
    end

    context 'with unsuccessful response' do
      let(:response_success) { false }

      before do
        payment.payment_method
          .should_receive(:credit)
          .with(credit_cents, payment.source, payment.transaction_id, {})
          .and_return(response)
      end

      it 'raises Spree::Core:GatewayError' do
        expect { subject }.to raise_error(Spree::Core::GatewayError, response_message)
      end
    end

    context 'with activemerchant gateway connection error' do
      let(:response_success) { false }

      before do
        payment.payment_method
          .should_receive(:credit)
          .with(credit_cents, payment.source, payment.transaction_id, {})
          .and_raise(ActiveMerchant::ConnectionError)
      end

      it 'raises Spree::Core::GatewayError' do
        expect { subject }.to raise_error(Spree::Core::GatewayError, Spree.t(:unable_to_connect_to_gateway))
      end
    end
  end

  describe '.check_environment' do
    subject { Spree::Refund.check_environment(payment) }

    let(:payment) { create(:payment, payment_method: payment_method) }
    let(:payment_method) { create(:credit_card_payment_method, environment: payment_method_environment) }
    let(:payment_method_environment) { 'test' }

    context 'correct payment method environment' do
      it 'does not raise' do
        expect { subject }.not_to raise_error
      end
    end

    context 'incorrect payment method environment' do
      let(:payment_method_environment) { 'development' }

      it 'raises a Spree::Core::GatewayError' do
        expect { subject }.to raise_error(Spree::Core::GatewayError)
      end
    end
  end

  describe '.check_amount' do

    subject { Spree::Refund.check_amount(amount) }

    context 'amount is less tha zero' do
      let(:amount) { -1.0 }

      it 'raises Spree::Core::GatewayError' do
        expect { subject }.to raise_error(Spree::Core::GatewayError, Spree.t(:refund_amount_must_be_greater_than_zero))
      end
    end

    context 'amount is zero' do
      let(:amount) { 0.0 }

      it 'raises Spree::Core::GatewayError' do
        expect { subject }.to raise_error(Spree::Core::GatewayError, Spree.t(:refund_amount_must_be_greater_than_zero))
      end
    end

    context 'amount is larger than zero' do
      let(:amount) { 10.0 }

      it 'does not raise an error' do
        expect { subject }.to_not raise_error
      end
    end
  end
end
