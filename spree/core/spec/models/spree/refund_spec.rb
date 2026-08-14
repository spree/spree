require 'spec_helper'

describe Spree::Refund, type: :model do
  describe 'shared examples' do
    before do
      allow_any_instance_of(Spree::Refund).to receive(:amount_is_less_than_or_equal_to_allowed_amount)
    end

    it_behaves_like 'metadata'
    it_behaves_like 'lifecycle events'
  end

  describe '#amount=' do
    let(:refund) { build(:refund) }
    let(:amount) { '1,599,99' }

    before do
      allow_any_instance_of(Spree::Refund).to receive(:amount_is_less_than_or_equal_to_allowed_amount)
      refund.amount = amount
    end

    it 'is expected to equal to localized number' do
      expect(refund.amount).to eq(Spree::LocalizedNumber.parse(amount))
    end
  end

  describe 'create' do
    subject { create(:refund, payment: payment, amount: amount, reason: refund_reason, transaction_id: nil) }

    let(:amount) { 100.0 }
    let(:amount_in_cents) { amount * 100 }

    let(:authorization) { generate(:refund_transaction_id) }

    let(:payment) { create(:payment, amount: payment_amount, payment_method: payment_method) }
    let(:payment_amount) { amount * 2 }
    let(:payment_method) { create(:credit_card_payment_method) }

    let(:refund_reason) { create(:refund_reason) }

    let(:gateway_response) do
      Spree::PaymentResponse.new(
        gateway_response_success,
        gateway_response_message,
        gateway_response_params,
        gateway_response_options
      )
    end
    let(:gateway_response_success) { true }
    let(:gateway_response_message) { '' }
    let(:gateway_response_params) { {} }
    let(:gateway_response_options) { {} }

    before do
      allow(payment.payment_method).
        to receive(:credit).
        with(amount_in_cents, payment.source, payment.transaction_id, originator: an_instance_of(Spree::Refund)).
        and_return(gateway_response)
    end

    context 'transaction id exists on creation' do
      subject { create(:refund, payment: payment, amount: amount, reason: refund_reason, transaction_id: transaction_id) }

      let(:transaction_id) { '12kfjas0' }

      it 'creates a refund record' do
        expect { subject }.to change { Spree::Refund.count }.by(1)
      end

      it 'maintains the transaction id' do
        expect(subject.reload.transaction_id).to eq transaction_id
      end

      it 'saves the amount' do
        expect(subject.reload.amount).to eq amount
      end

      it 'does not attempt to process a transaction' do
        expect(payment.payment_method).not_to receive(:credit)
        subject
      end
    end

    context 'processing is successful' do
      let(:gateway_response_options) { { authorization: authorization } }

      it 'creates a refund' do
        expect { subject }.to change { Spree::Refund.count }.by(1)
      end

      it 'instruments the credit gateway call as gateway.spree_payments' do
        notifications = []
        subscriber = ActiveSupport::Notifications.subscribe('gateway.spree_payments') do |*, payload|
          notifications << payload
        end

        subject

        expect(notifications.sole).to include(action: 'credit', payment_method_type: payment_method.type)
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      it 'return the newly created refund' do
        expect(subject).to be_a(Spree::Refund)
      end

      it 'saves the returned authorization value' do
        expect(subject.reload.transaction_id).to eq authorization
      end

      it 'saves the passed amount as the refund amount' do
        expect(subject.amount).to eq amount
      end

      it 'attempts to process a transaction' do
        expect(payment.payment_method).to receive(:credit).once
        subject
      end

      it 'recalculates order totals' do
        expect { subject }.to change { payment.order.reload.updated_at }
      end
    end

    context 'processing fails' do
      let(:gateway_response_success) { false }
      let(:gateway_response_message) { 'failure message' }

      it 'raises error and not create a refund' do
        expect do
          expect { subject }.to raise_error(Spree::Core::GatewayError, gateway_response_message)
        end.not_to change { Spree::Refund.count }
      end
    end

    context 'without payment profiles supported' do
      before do
        allow(payment.payment_method).to receive(:payment_profiles_supported?).and_return(false)
      end

      it 'does not supply the payment source' do
        expect(payment.payment_method).
          to receive(:credit).
          with(amount * 100, payment.transaction_id, originator: an_instance_of(Spree::Refund)).
          and_return(gateway_response)

        subject
      end
    end

    context 'with payment profiles supported' do
      before do
        allow(payment.payment_method).to receive(:payment_profiles_supported?).and_return(true)
      end

      it 'supplies the payment source' do
        expect(payment.payment_method).
          to receive(:credit).
          with(amount_in_cents, payment.source, payment.transaction_id, originator: an_instance_of(Spree::Refund)).
          and_return(gateway_response)

        subject
      end
    end

    context 'with a gateway connection error' do
      before do
        message = 'gateway_error'
        expect(payment.payment_method).to receive(:credit).with(
          amount_in_cents,
          payment.source,
          payment.transaction_id,
          originator: an_instance_of(Spree::Refund)
        ).and_raise(Spree::PaymentConnectionError.new(message))
      end

      it 'raises Spree::Core::GatewayError' do
        expect { subject }.to raise_error(Spree::Core::GatewayError, Spree.t(:unable_to_connect_to_gateway))
      end
    end

    context 'with amount too large' do
      let(:payment_amount) { 10 }
      let(:amount) { payment_amount * 2 }

      it 'is invalid' do
        expect { subject }.to raise_error { |error|
          expect(error).to be_a(ActiveRecord::RecordInvalid)
          expect(error.record.errors.full_messages).to eq ["Amount #{I18n.t('activerecord.errors.models.spree/refund.attributes.amount.greater_than_allowed')}"]
        }
      end
    end
  end

  describe '#return_line_items' do
    subject { refund.return_line_items }

    let(:refund) { create(:refund, amount: 10, originator: originator) }

    context 'when the refund came from a return' do
      let(:originator) { create(:received_return) }

      it { is_expected.to match_array(originator.return_line_items) }
    end

    context 'when the refund was issued manually' do
      let(:originator) { nil }

      it { is_expected.to eq([]) }
    end
  end
end
