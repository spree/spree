require 'spec_helper'

RSpec.shared_examples 'check total store credit from payments' do
  context 'with valid payments' do
    subject { record }

    let(:record) { new_record(user: create(:user), total: 100.00) }
    let!(:payment) { create_store_credit_payment(record, amount: 20.0) }
    let!(:second_payment) { create_store_credit_payment(record, amount: 30.0) }

    it 'returns the sum of the payment amounts' do
      expect(subject.total_applicable_store_credit).to eq(payment.amount + second_payment.amount)
    end
  end

  context 'without valid payments' do
    subject { record }

    let(:record) { new_record }

    it 'returns 0' do
      expect(subject.total_applicable_store_credit).to be_zero
    end
  end
end

RSpec.shared_examples 'a store credits host' do
  describe '#add_store_credit_payments' do
    subject { record.add_store_credit_payments }

    let(:record_total) { 500.00 }

    before { create(:store_credit_payment_method) }

    context 'there is no store credit' do
      let(:record) { guest_record(total: record_total) }

      before do
        # callbacks recalculate total based on line items
        # this ensures the total is what we expect
        record.update_column(:total, record_total)
        subject
        record.reload
      end

      it 'does not create a store credit payment' do
        expect(record.payments.count).to eq 0
      end
    end

    context 'there is enough store credit to pay for the entire record' do
      let(:store_credit) { create(:store_credit, amount: record_total) }
      let(:record) { new_record(user: store_credit.user, total: record_total) }

      before do
        subject
        record.reload
      end

      it 'creates a store credit payment for the full amount' do
        expect(record.payments.count).to eq 1
        expect(record.payments.first).to be_store_credit
        expect(record.payments.first.amount).to eq record_total
      end
    end

    context 'the available store credit is not enough to pay for the entire record' do
      let(:expected_cc_total) { 100.0 }
      let(:store_credit_total) { record_total - expected_cc_total }
      let(:store_credit) { create(:store_credit, amount: store_credit_total) }
      let(:record) { new_record(user: store_credit.user, total: record_total) }

      before do
        record.update_column(:total, record_total)
        subject
        record.reload
      end

      it 'creates a store credit payment for the available amount' do
        expect(record.payments.count).to eq 1
        expect(record.payments.first).to be_store_credit
        expect(record.payments.first.amount).to eq store_credit_total
      end
    end

    context 'there are multiple store credits' do
      context 'they have different credit type priorities' do
        let(:amount_difference) { 100 }
        let!(:primary_store_credit) { create(:store_credit, amount: (record_total - amount_difference)) }
        let!(:secondary_store_credit) do
          create(:store_credit, amount: record_total, user: primary_store_credit.user,
                                credit_type: create(:secondary_credit_type))
        end
        let(:record) { new_record(user: primary_store_credit.user, total: record_total) }

        before do
          Timecop.scale(3600)
          subject
          record.reload
        end

        after { Timecop.return }

        it 'uses the primary store credit type over the secondary' do
          primary_payment = record.payments.first
          secondary_payment = record.payments.last

          expect(record.payments.size).to eq 2
          expect(primary_payment.source).to eq primary_store_credit
          expect(secondary_payment.source).to eq secondary_store_credit
          expect(primary_payment.amount).to eq(record_total - amount_difference)
          expect(secondary_payment.amount).to eq(amount_difference)
        end
      end
    end
  end

  describe '#remove_store_credit_payments' do
    subject { record.remove_store_credit_payments }

    let(:record_total) { 500.00 }
    let(:record) { new_record(user: store_credit.user, total: record_total) }

    context 'when the record is not complete' do
      let(:store_credit) { create(:store_credit, amount: record_total - 1) }

      before do
        create(:store_credit_payment_method)
        record.add_store_credit_payments
      end

      it { expect { subject }.to change { record.payments.checkout.store_credits.count }.from(1).to(0) }
      it { expect { subject }.to change { record.payments.with_state(:invalid).store_credits.count }.from(0).to(1) }
    end

    context 'when the record is complete' do
      let(:record) { completed_record_with_store_credit_payment }
      let(:store_credit_payments) { record.payments.checkout.store_credits }

      before do
        subject
        record.reload
      end

      it { expect(record.payments.checkout.store_credits).to eq store_credit_payments }
    end
  end

  describe '#covered_by_store_credit' do
    context "record doesn't have an associated user" do
      subject { record.covered_by_store_credit? }

      let(:record) { guest_record }

      it { is_expected.to be(false) }
    end

    context 'record has an associated user' do
      subject { record.covered_by_store_credit? }

      let(:record) { new_record(user: user, total: record_total) }
      let(:user) { create(:user) }
      let(:record_total) { 10.0 }

      context 'user has enough store credit to pay for the record' do
        let!(:store_credit_payment) { create_store_credit_payment(record, source: store_credit, amount: 10.0) }
        let(:store_credit) { create(:store_credit, amount: 10.0, store: record.store, user: record.user) }

        it { is_expected.to be(true) }
      end

      context 'user does not have enough store credit to pay for the record' do
        before do
          allow(user).to receive(:total_available_store_credit).and_return(0.0)
          allow(subject).to receive(:total).and_return(5.0)
        end

        it { is_expected.to be(false) }
      end

      context 'record total is zero' do
        let(:record_total) { 0.0 }

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#total_available_store_credit' do
    context 'record does not have an associated user' do
      subject { guest_record }

      it 'returns 0' do
        expect(subject.total_available_store_credit).to be_zero
      end
    end

    context 'record has an associated user' do
      subject { new_record(user: user) }

      let(:user) { create(:user) }
      let(:available_store_credit) { 25.0 }

      before do
        allow(user).to receive(:total_available_store_credit).and_return(available_store_credit)
      end

      it "returns the user's available store credit" do
        expect(subject.total_available_store_credit).to eq available_store_credit
      end

      context 'when store is provided' do
        let!(:store) { @default_store }
        let!(:second_store) { create(:store) }
        let!(:store_credit) { create(:store_credit, amount: '100', user: user, store: store) }

        before do
          allow(user).to receive(:total_available_store_credit).and_call_original
        end

        context 'and has store credits associated' do
          before do
            expect(subject).to receive(:store).and_return(store)
          end

          it "returns the user's available store credit" do
            expect(subject.total_available_store_credit).to eq(100)
          end
        end

        context 'and has no store credits associated' do
          before do
            expect(subject).to receive(:store).and_return(second_store)
          end

          it "returns the user's available store credit" do
            expect(subject.total_available_store_credit).to eq(0)
          end
        end
      end
    end
  end

  describe '#available_store_credits' do
    subject { record.available_store_credits }

    context 'record does not have an associated user' do
      let(:record) { guest_record }

      it { is_expected.to be_empty }
    end

    context 'record has an associated user' do
      let(:record) { new_record(user: user, currency: 'USD') }
      let(:user) { create(:user) }

      let!(:store_credit_1) { create(:store_credit, user: user, amount: 10, currency: 'USD') }
      let!(:store_credit_2) { create(:store_credit, user: user, amount: 15, currency: 'USD') }
      let!(:store_credit_3) { create(:store_credit, user: user, amount: 20, currency: 'EUR') }

      it 'returns the user available store credits' do
        expect(subject).to eq([store_credit_2, store_credit_1])
      end
    end
  end

  describe '#could_use_store_credit?' do
    let!(:store_credit_payment_method) { create(:store_credit_payment_method) }

    context 'record does not have an associated user' do
      subject { guest_record }

      it { expect(subject.could_use_store_credit?).to be false }
    end

    context 'record has an associated user' do
      subject { new_record(user: user) }

      let(:user) { create(:user) }

      context 'without store credit' do
        it { expect(subject.could_use_store_credit?).to be false }
      end

      context 'with store credit' do
        let(:available_store_credit) { 25.0 }

        before do
          allow(user).to receive(:total_available_store_credit).and_return(available_store_credit)
        end

        it { expect(subject.could_use_store_credit?).to be true }
      end

      context 'without active Store Credit Payment' do
        let(:available_store_credit) { 25.0 }

        before do
          allow(user).to receive(:total_available_store_credit).and_return(available_store_credit)
          store_credit_payment_method.update_attribute(:active, false)
        end

        it { expect(subject.could_use_store_credit?).to be false }
      end

      context 'without Store Credit Payment' do
        let(:available_store_credit) { 25.0 }

        before do
          allow(user).to receive(:total_available_store_credit).and_return(available_store_credit)
          store_credit_payment_method.destroy
        end

        it { expect(subject.could_use_store_credit?).to be false }
      end
    end
  end

  describe '#order_total_after_store_credit' do
    subject { new_record(total: record_total) }

    let(:record_total) { 100.0 }

    before do
      allow(subject).to receive(:total_applicable_store_credit).and_return(applicable_store_credit)
    end

    context "record's user has store credits" do
      let(:applicable_store_credit) { 10.0 }

      it 'deducts the applicable store credit' do
        expect(subject.order_total_after_store_credit).to eq(record_total - applicable_store_credit)
      end
    end

    context "record's user does not have any store credits" do
      let(:applicable_store_credit) { 0.0 }

      it 'returns the record total' do
        expect(subject.order_total_after_store_credit).to eq record_total
      end
    end
  end

  describe '#total_applicable_store_credit' do
    context 'record has payments (mid-checkout)' do
      include_examples 'check total store credit from payments'
    end

    context 'record is completed' do
      let(:record) { new_record(user: create(:user), total: 100.00) }

      it 'reports the actually applied payments, not the theoretical maximum' do
        payment = create_store_credit_payment(record, amount: 20.0)
        second_payment = create_store_credit_payment(record, amount: 30.0)
        mark_completed(record)

        expect(record.reload.total_applicable_store_credit).to eq(payment.amount + second_payment.amount)
      end
    end

    context 'record has no payments and is not completed' do
      context 'the associated user has store credits' do
        subject { record }

        let(:store) { @default_store }
        let(:store_credit) { create(:store_credit, store: store) }
        let(:record) { new_record(user: store_credit.user) }

        context 'the store credit is more than the record total' do
          let(:record_total) { store_credit.amount - 1 }

          before { record.update(total: record_total) }

          it 'returns the record total' do
            expect(subject.total_applicable_store_credit).to eq record_total
          end
        end

        context 'the store credit is less than the record total' do
          let(:record_total) { store_credit.amount * 10 }

          before { record.update(total: record_total) }

          it 'returns the store credit amount' do
            expect(subject.total_applicable_store_credit).to eq store_credit.amount
          end
        end
      end

      context 'the associated user does not have store credits' do
        subject { new_record(user: create(:user)) }

        it 'returns 0' do
          expect(subject.total_applicable_store_credit).to be_zero
        end
      end

      context 'the record does not have an associated user' do
        subject { guest_record }

        it 'returns 0' do
          expect(subject.total_applicable_store_credit).to be_zero
        end
      end
    end
  end

  describe '#total_applied_store_credit' do
    subject(:total_applied_store_credit) { record.total_applied_store_credit }

    let(:record) { new_record(user: create(:user), total: 100.00) }

    context 'with valid payments' do
      let(:valid_payment) { 10.0 }
      let(:valid_payment_2) { 20.0 }
      let(:invalid_payment) { 21.0 }
      let(:other_record_payment) { 22.0 }

      before do
        create_store_credit_payment(record, status: 'completed', amount: valid_payment)
        create_store_credit_payment(record, status: 'completed', amount: valid_payment_2)
        create_store_credit_payment(record, status: 'invalid', amount: invalid_payment)
        create_store_credit_payment(new_record(user: create(:user), total: 100.00), status: 'completed', amount: other_record_payment)
      end

      it 'returns the sum of the payment amounts' do
        expect(total_applied_store_credit).to eq(valid_payment + valid_payment_2)
      end

      context 'when payments are loaded' do
        before { record.payments.load }

        it 'returns the sum of the payment amounts' do
          expect(total_applied_store_credit).to eq(valid_payment + valid_payment_2)
        end
      end
    end

    context 'without valid payments' do
      it 'returns 0' do
        expect(total_applied_store_credit).to be_zero
      end
    end
  end

  describe '#using_store_credit?' do
    subject { new_record }

    it 'reflects whether store credit is applied' do
      allow(subject).to receive(:total_applied_store_credit).and_return(10.0)
      expect(subject.using_store_credit?).to be true

      allow(subject).to receive(:total_applied_store_credit).and_return(0.0)
      expect(subject.using_store_credit?).to be false
    end
  end

  describe 'display money helpers' do
    subject { new_record }

    it '#display_total_applicable_store_credit returns a negative money amount' do
      allow(subject).to receive(:total_applicable_store_credit).and_return(10.00)

      expect(subject.display_total_applicable_store_credit).to be_a(Spree::Money)
      expect(subject.display_total_applicable_store_credit.amount_in_cents).to eq(-1000)
    end

    it '#display_total_applied_store_credit returns a negative money amount' do
      allow(subject).to receive(:total_applied_store_credit).and_return(10.00)

      expect(subject.display_total_applied_store_credit).to be_a(Spree::Money)
      expect(subject.display_total_applied_store_credit.amount_in_cents).to eq(-1000)
    end

    it '#display_order_total_after_store_credit returns the after-credit amount' do
      allow(subject).to receive(:order_total_after_store_credit).and_return(10.00)

      expect(subject.display_order_total_after_store_credit.amount_in_cents).to eq(1000)
    end

    it '#display_total_available_store_credit returns the available amount' do
      allow(subject).to receive(:total_available_store_credit).and_return(10.00)

      expect(subject.display_total_available_store_credit.amount_in_cents).to eq(1000)
    end

    it "#display_store_credit_remaining_after_capture returns available minus applied" do
      allow(subject).to receive(:total_available_store_credit).and_return(10.00)
      allow(subject).to receive(:total_applicable_store_credit).and_return(5.00)

      expect(subject.display_store_credit_remaining_after_capture.amount_in_cents).to eq(500)
    end
  end
end

RSpec.describe Spree::Purchase::StoreCredits do
  context 'included in Spree::Cart' do
    def new_record(user: nil, total: nil, currency: nil)
      create(:cart, { store: @default_store, customer: user, total: total, currency: currency }.compact)
    end

    def guest_record(total: nil)
      create(:cart, { store: @default_store, customer: nil, total: total }.compact)
    end

    def create_store_credit_payment(record, **attributes)
      create(:store_credit_payment, cart: record, order: nil, **attributes)
    end

    def mark_completed(record)
      record.update_columns(completed_at: Time.current)
    end

    def completed_record_with_store_credit_payment
      cart = new_record(user: create(:user), total: 50.0)
      create(:store_credit_payment, cart: cart, order: nil, amount: 50.0)
      mark_completed(cart)
      cart
    end

    it_behaves_like 'a store credits host'
  end

  context 'included in Spree::Order' do
    def new_record(user: nil, total: nil, currency: nil)
      create(:order, { store: @default_store, user: user, total: total, currency: currency }.compact)
    end

    def guest_record(total: nil)
      create(:store_credits_order_without_user, { total: total }.compact)
    end

    def create_store_credit_payment(record, **attributes)
      create(:store_credit_payment, order: record, **attributes)
    end

    def mark_completed(record)
      record.update_columns(completed_at: Time.current, status: 'placed')
    end

    def completed_record_with_store_credit_payment
      create(:completed_order_with_store_credit_payment)
    end

    it_behaves_like 'a store credits host'
  end
end
