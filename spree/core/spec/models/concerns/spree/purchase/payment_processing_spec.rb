require 'spec_helper'

RSpec.shared_examples 'a payment processing host' do
  describe '#process_payments!' do
    let!(:record) { new_record_with_line_items }
    let!(:payment) do
      payment = create_payment(record, amount: 10, state: payment_state)
      record.payments << payment
      payment
    end

    let(:payment_state) { 'checkout' }
    let(:unprocessed_payments) { [payment] }
    let(:pending_payments) { [] }
    let(:total) { 10 }

    before do
      allow(record).to receive_messages(
        unprocessed_payments: unprocessed_payments,
        pending_payments: pending_payments,
        total: total
      )
    end

    it 'processes the payments' do
      expect(payment).to receive(:process!)
      expect(record.process_payments!).to be_truthy
    end

    # Regression spec for https://github.com/spree/spree/issues/5436
    it 'raises an error if there are no payments to process' do
      allow(record).to receive_messages unprocessed_payments: []
      expect(payment).not_to receive(:process!)
      expect(record.process_payments!).to be_falsey
    end

    context 'when there are pending payments' do
      let(:payment_state) { 'pending' }
      let(:pending_payments) { [payment] }
      let(:unprocessed_payments) { [] }

      it 'skips processing the payments' do
        expect(payment).not_to receive(:process!)
        expect(record.process_payments!).to be_nil
      end

      context 'when there is other unprocessed payment' do
        let(:other_payment) { create_payment(record, amount: 5, state: 'checkout') }
        let(:unprocessed_payments) { [other_payment] }

        before do
          record.payments << other_payment
        end

        it 'processes only the other payment' do
          expect(payment).not_to receive(:process!)
          expect(other_payment).to receive(:process!)

          expect(record.process_payments!).to be_truthy
        end
      end
    end

    context 'when a payment raises a GatewayError' do
      before { expect(payment).to receive(:process!).and_raise(Spree::Core::GatewayError) }

      it 'returns false' do
        expect(record.process_payments!).to be false
      end

      it 'records the gateway message so completion can report it' do
        record.process_payments!

        expect(record.errors[:base]).to be_present
      end
    end

    # Regression spec for https://github.com/spree/spree/issues/8148
    it 'updates the record with correct payment total' do
      stub_store_preferences(auto_capture: true)
      record.process_payments!

      expect(payment).to be_completed
      expect(record.payment_total).to eq payment.amount
    end
  end

  describe '#authorize_payments!' do
    subject { record.authorize_payments! }

    let(:record) { new_record_with_line_items }
    let(:payment) { create(:payment) }

    before { allow(record).to receive_messages unprocessed_payments: [payment], total: 10 }

    it 'processes payments with authorize!' do
      expect(payment).to receive(:authorize!)
      subject
    end

    it { is_expected.to be_truthy }
  end

  describe '#capture_payments!' do
    subject { record.capture_payments! }

    let(:record) { new_record_with_line_items }
    let(:payment) { create(:payment) }

    before { allow(record).to receive_messages unprocessed_payments: [payment], total: 10 }

    it 'processes payments with purchase!' do
      expect(payment).to receive(:purchase!)
      subject
    end

    it { is_expected.to be_truthy }
  end

  describe '#pending_payments / #unprocessed_payments' do
    let(:record) { new_record_with_line_items }

    it 'partitions payments by state' do
      # Pending first — creating a new payment invalidates existing
      # checkout-state payments (Payment#invalidate_old_payments).
      pending_payment = create_payment(record, amount: 5, state: 'pending')
      checkout_payment = create_payment(record, amount: 5, state: 'checkout')

      expect(record.pending_payments).to contain_exactly(pending_payment)
      expect(record.unprocessed_payments).to contain_exactly(checkout_payment)
    end
  end

  describe '#payment_methods' do
    let(:record) { new_record_with_line_items }
    let(:store) { record.store }

    it 'lists active front-end methods available for this record' do
      available = create(:credit_card_payment_method, store: store)
      inactive = create(:credit_card_payment_method, store: store, active: false)
      back_office_only = create(:credit_card_payment_method, store: store, storefront_visible: false)

      expect(record.payment_methods).to include(available)
      expect(record.payment_methods).not_to include(inactive)
      expect(record.payment_methods).not_to include(back_office_only)
    end

    it 'excludes methods that report themselves unavailable for the record' do
      # Store credit is only offered when the customer actually holds credit.
      store_credit_method = create(:store_credit_payment_method, store: store)

      expect(record.payment_methods).not_to include(store_credit_method)
    end
  end

  describe '#payment_required?' do
    let(:record) { new_record_with_line_items }

    context 'total is zero' do
      before { allow(record).to receive_messages(total: 0) }

      it { expect(record.payment_required?).to be false }
    end

    context 'total > zero' do
      before { allow(record).to receive_messages(total: 1) }

      it { expect(record.payment_required?).to be true }
    end
  end

  describe '#confirmation_required?' do
    subject { record.confirmation_required? }

    let(:record) { new_record_with_line_items }

    it 'is computed from data only' do
      expect(record.class.new.confirmation_required?).to be(false)
    end

    context 'Spree::Config[:always_include_confirm_step] == true' do
      before { Spree::Config[:always_include_confirm_step] = true }

      it 'returns true if payments empty' do
        expect(record.class.new.confirmation_required?).to be(true)
      end
    end

    context 'Spree::Config[:always_include_confirm_step] == false' do
      it 'returns false if payments empty' do
        expect(record.class.new.confirmation_required?).to be(false)
      end

      it 'does not bomb out with an unpersisted payment' do
        blank_record = record.class.new
        blank_record.payments.build

        expect(blank_record.confirmation_required?).to be(false)
      end
    end

    context 'when the payment does not require confirmation' do
      before do
        record.update_column(:total, 50)
        create_payment(record, amount: 50)

        allow_any_instance_of(Spree::Gateway::Bogus).to receive(:confirmation_required?).and_return(false)
      end

      it { is_expected.to be(false) }
    end

    context 'when at least one payment method requires confirmation' do
      before do
        record.update_column(:total, 50)
        create_payment(record, amount: 50)
      end

      it { is_expected.to be(true) }
    end
  end
end

RSpec.describe Spree::Purchase::PaymentProcessing do
  context 'included in Spree::Cart' do
    def new_record_with_line_items
      create(:cart_with_line_items, store: @default_store)
    end

    def create_payment(record, **attributes)
      create(:payment, cart: record, order: nil, **attributes)
    end

    it_behaves_like 'a payment processing host'
  end

  context 'included in Spree::Order' do
    def new_record_with_line_items
      create(:order_with_line_items, store: @default_store)
    end

    def create_payment(record, **attributes)
      create(:payment, order: record, **attributes)
    end

    it_behaves_like 'a payment processing host'

    it 'bridges the deprecated collect_frontend_payment_methods to payment_methods' do
      order = new_record_with_line_items
      available = create(:credit_card_payment_method, store: order.store)

      expect(Spree::Deprecation).to receive(:warn).with(/collect_frontend_payment_methods/)
      expect(order.collect_frontend_payment_methods).to include(available)
    end
  end
end
