require 'spec_helper'

shared_examples 'check total store credit from payments' do
  context 'with valid payments' do
    subject { order }

    let(:order) { payment.order }
    let!(:payment) { create(:store_credit_payment) }
    let!(:second_payment) { create(:store_credit_payment, order: order) }

    it 'returns the sum of the payment amounts' do
      expect(subject.total_applicable_store_credit).to eq (payment.amount + second_payment.amount)
    end
  end

  context 'without valid payments' do
    subject { order }

    let(:order) { create(:order) }

    it 'returns 0' do
      expect(subject.total_applicable_store_credit).to be_zero
    end
  end
end

describe 'Order' do
  describe '#add_store_credit_payments' do
    subject { order.add_store_credit_payments }

    let(:order_total) { 500.00 }

    before { create(:store_credit_payment_method) }

    context 'there is no store credit' do
      let(:order) { create(:store_credits_order_without_user, total: order_total) }

      before do
        # callbacks recalculate total based on line items
        # this ensures the total is what we expect
        order.update_column(:total, order_total)
        subject
        order.reload
      end

      it 'does not create a store credit payment' do
        expect(order.payments.count).to eq 0
      end
    end

    context 'there is enough store credit to pay for the entire order' do
      let(:store_credit) { create(:store_credit, amount: order_total) }
      let(:order) { create(:order, user: store_credit.user, total: order_total) }

      before do
        subject
        order.reload
      end

      it 'creates a store credit payment for the full amount' do
        expect(order.payments.count).to eq 1
        expect(order.payments.first).to be_store_credit
        expect(order.payments.first.amount).to eq order_total
      end
    end

    context 'the available store credit is not enough to pay for the entire order' do
      let(:expected_cc_total) { 100.0 }
      let(:store_credit_total) { order_total - expected_cc_total }
      let(:store_credit) { create(:store_credit, amount: store_credit_total) }
      let(:order) { create(:order, user: store_credit.user, total: order_total) }

      before do
        # callbacks recalculate total based on line items
        # this ensures the total is what we expect
        order.update_column(:total, order_total)
        subject
        order.reload
      end

      it 'creates a store credit payment for the available amount' do
        expect(order.payments.count).to eq 1
        expect(order.payments.first).to be_store_credit
        expect(order.payments.first.amount).to eq store_credit_total
      end
    end

    context 'there are multiple store credits' do
      context 'they have different credit type priorities' do
        let(:amount_difference) { 100 }
        let!(:primary_store_credit) { create(:store_credit, amount: (order_total - amount_difference)) }
        let!(:secondary_store_credit) do
          create(:store_credit, amount: order_total, user: primary_store_credit.user,
                                credit_type: create(:secondary_credit_type))
        end
        let(:order) { create(:order, user: primary_store_credit.user, total: order_total) }

        before do
          Timecop.scale(3600)
          subject
          order.reload
        end

        after { Timecop.return }

        it 'uses the primary store credit type over the secondary' do
          primary_payment = order.payments.first
          secondary_payment = order.payments.last

          expect(order.payments.size).to eq 2
          expect(primary_payment.source).to eq primary_store_credit
          expect(secondary_payment.source).to eq secondary_store_credit
          expect(primary_payment.amount).to eq(order_total - amount_difference)
          expect(secondary_payment.amount).to eq(amount_difference)
        end
      end
    end
  end

  describe '#remove_store_credit_payments' do
    subject { order.remove_store_credit_payments }

    let(:order_total) { 500.00 }
    let(:order) { create(:order, user: store_credit.user, total: order_total) }

    context 'when order is not complete' do
      let(:store_credit) { create(:store_credit, amount: order_total - 1) }

      before do
        create(:store_credit_payment_method)
        order.add_store_credit_payments
      end

      it { expect { subject }.to change { order.payments.checkout.store_credits.count }.from(1).to(0) }
      it { expect { subject }.to change { order.payments.with_state(:invalid).store_credits.count }.from(0).to(1) }
    end

    context 'when order is complete' do
      let(:order) { create(:completed_order_with_store_credit_payment) }
      let(:store_credit_payments) { order.payments.checkout.store_credits }

      before do
        subject
        order.reload
      end

      it { expect(order.payments.checkout.store_credits).to eq store_credit_payments }
    end
  end

  describe '#covered_by_store_credit' do
    context "order doesn't have an associated user" do
      subject { create(:store_credits_order_without_user) }

      it 'returns false' do
        expect(subject.covered_by_store_credit).to be false
      end
    end

    context 'order has an associated user' do
      subject { create(:order, user: user) }

      let(:user) { create(:user) }

      context 'user has enough store credit to pay for the order' do
        before do
          allow(user).to receive(:total_available_store_credit).and_return(10.0)
          allow(subject).to receive(:total).and_return(5.0)
        end

        it 'returns true' do
          expect(subject.covered_by_store_credit).to be true
        end
      end

      context 'user does not have enough store credit to pay for the order' do
        before do
          allow(user).to receive(:total_available_store_credit).and_return(0.0)
          allow(subject).to receive(:total).and_return(5.0)
        end

        it 'returns false' do
          expect(subject.covered_by_store_credit).to be false
        end
      end
    end
  end

  describe '#total_available_store_credit' do
    context 'order does not have an associated user' do
      subject { create(:store_credits_order_without_user) }

      it 'returns 0' do
        expect(subject.total_available_store_credit).to be_zero
      end
    end

    context 'order has an associated user' do
      subject { create(:order, user: user) }

      let(:user) { create(:user) }
      let(:available_store_credit) { 25.0 }

      before do
        allow(user).to receive(:total_available_store_credit).and_return(available_store_credit)
      end

      it "returns the user's available store credit" do
        expect(subject.total_available_store_credit).to eq available_store_credit
      end
    end
  end

  describe '#could_use_store_credit?' do
    context 'order does not have an associated user' do
      subject { create(:store_credits_order_without_user) }

      it { expect(subject.could_use_store_credit?).to be false }
    end

    context 'order has an associated user' do
      subject { create(:order, user: user) }

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
    end
  end

  describe '#order_total_after_store_credit' do
    subject { create(:order, total: order_total) }

    let(:order_total) { 100.0 }

    before do
      allow(subject).to receive(:total_applicable_store_credit).and_return(applicable_store_credit)
    end

    context "order's user has store credits" do
      let(:applicable_store_credit) { 10.0 }

      it 'deducts the applicable store credit' do
        expect(subject.order_total_after_store_credit).to eq (order_total - applicable_store_credit)
      end
    end

    context "order's user does not have any store credits" do
      let(:applicable_store_credit) { 0.0 }

      it 'returns the order total' do
        expect(subject.order_total_after_store_credit).to eq order_total
      end
    end
  end

  describe '#total_applicable_store_credit' do
    context 'order is in the confirm state' do
      before { order.update_attributes(state: 'confirm') }
      include_examples 'check total store credit from payments'
    end

    context 'order is completed' do
      before { order.update_attributes(state: 'complete') }
      include_examples 'check total store credit from payments'
    end

    context 'order is in any state other than confirm or complete' do
      context 'the associated user has store credits' do
        subject { order }

        let(:store_credit) { create(:store_credit) }
        let(:order) { create(:order, user: store_credit.user) }

        context 'the store credit is more than the order total' do
          let(:order_total) { store_credit.amount - 1 }

          before { order.update_attributes(total: order_total) }

          it 'returns the order total' do
            expect(subject.total_applicable_store_credit).to eq order_total
          end
        end

        context 'the store credit is less than the order total' do
          let(:order_total) { store_credit.amount * 10 }

          before { order.update_attributes(total: order_total) }

          it 'returns the store credit amount' do
            expect(subject.total_applicable_store_credit).to eq store_credit.amount
          end
        end
      end

      context 'the associated user does not have store credits' do
        subject { order }

        let(:order) { create(:order) }

        it 'returns 0' do
          expect(subject.total_applicable_store_credit).to be_zero
        end
      end

      context 'the order does not have an associated user' do
        subject { create(:store_credits_order_without_user) }

        it 'returns 0' do
          expect(subject.total_applicable_store_credit).to be_zero
        end
      end
    end
  end

  describe '#total_applied_store_credit' do
    context 'with valid payments' do
      subject { order }

      let(:order) { payment.order }
      let!(:payment) { create(:store_credit_payment) }
      let!(:second_payment) { create(:store_credit_payment, order: order) }

      it 'returns the sum of the payment amounts' do
        expect(subject.total_applied_store_credit).to eq (payment.amount + second_payment.amount)
      end
    end

    context 'without valid payments' do
      subject { order }

      let(:order) { create(:order) }

      it 'returns 0' do
        expect(subject.total_applied_store_credit).to be_zero
      end
    end
  end

  describe '#using_store_credit?' do
    subject { create(:order) }

    context 'order has store credit payment' do
      before { allow(subject).to receive(:total_applied_store_credit).and_return(10.0) }
      it { expect(subject.using_store_credit?).to be true }
    end

    context 'order has no store credit payments' do
      before { allow(subject).to receive(:total_applied_store_credit).and_return(0.0) }
      it { expect(subject.using_store_credit?).to be false }
    end
  end

  describe '#display_total_applicable_store_credit' do
    subject { create(:order) }

    let(:total_applicable_store_credit) { 10.00 }

    before do
      allow(subject).to receive(:total_applicable_store_credit).and_return(total_applicable_store_credit)
    end

    it 'returns a money instance' do
      expect(subject.display_total_applicable_store_credit).to be_a(Spree::Money)
    end

    it 'returns a negative amount' do
      expect(subject.display_total_applicable_store_credit.amount_in_cents).to eq (total_applicable_store_credit * -100.0)
    end
  end

  describe '#display_total_applied_store_credit' do
    subject { create(:order) }

    let(:total_applied_store_credit) { 10.00 }

    before do
      allow(subject).to receive(:total_applied_store_credit).and_return(total_applied_store_credit)
    end

    it 'returns a money instance' do
      expect(subject.display_total_applied_store_credit).to be_a(Spree::Money)
    end

    it 'returns a negative amount' do
      expect(subject.display_total_applied_store_credit.amount_in_cents).to eq (total_applied_store_credit * -100.0)
    end
  end

  describe '#display_order_total_after_store_credit' do
    subject { create(:order) }

    let(:order_total_after_store_credit) { 10.00 }

    before do
      allow(subject).to receive(:order_total_after_store_credit).and_return(order_total_after_store_credit)
    end

    it 'returns a money instance' do
      expect(subject.display_order_total_after_store_credit).to be_a(Spree::Money)
    end

    it 'returns the order_total_after_store_credit amount' do
      expect(subject.display_order_total_after_store_credit.amount_in_cents).to eq (order_total_after_store_credit * 100.0)
    end
  end

  describe '#display_total_available_store_credit' do
    subject { create(:order) }

    let(:total_available_store_credit) { 10.00 }

    before do
      allow(subject).to receive(:total_available_store_credit).and_return(total_available_store_credit)
    end

    it 'returns a money instance' do
      expect(subject.display_total_available_store_credit).to be_a(Spree::Money)
    end

    it 'returns the total_available_store_credit amount' do
      expect(subject.display_total_available_store_credit.amount_in_cents).to eq (total_available_store_credit * 100.0)
    end
  end

  describe '#display_store_credit_remaining_after_capture' do
    subject { create(:order) }

    let(:total_available_store_credit)  { 10.00 }
    let(:total_applicable_store_credit) { 5.00 }

    before do
      allow(subject).to receive(:total_available_store_credit).and_return(total_available_store_credit)
      allow(subject).to receive(:total_applicable_store_credit).and_return(total_applicable_store_credit)
    end

    it 'returns a money instance' do
      expect(subject.display_store_credit_remaining_after_capture).to be_a(Spree::Money)
    end

    it "returns all of the user's available store credit minus what's applied to the order amount" do
      amount_remaining = total_available_store_credit - total_applicable_store_credit
      expect(subject.display_store_credit_remaining_after_capture.amount_in_cents).to eq (amount_remaining * 100.0)
    end
  end
end
