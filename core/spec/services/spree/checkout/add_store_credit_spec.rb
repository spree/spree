require 'spec_helper'

describe Spree::Checkout::AddStoreCredit, type: :service do
  let(:store) { @default_store }

  describe '#call' do
    subject { described_class.call(order: order) }

    let(:order_total) { 500.00 }

    before do
      create(:store_credit_payment_method, stores: [store])
      allow(order.updater).to receive(:run_hooks)
    end

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

      it 'returns error' do
        expect(subject.success?).to eq(false)
        expect(subject.error.to_s).to eq('User does not have any Store Credits available')
        expect(order.updater).not_to have_received(:run_hooks)
      end
    end

    context 'there is enough store credit to pay for the entire order' do
      subject { described_class.call(order: order, amount: requested_amount) }

      let(:store_credit) { create(:store_credit, amount: order_total, store: store) }
      let(:order) { create(:order, user: store_credit.user, total: order_total, store: store) }

      context 'with no amount specified' do
        let(:requested_amount) { nil }

        it 'creates a store credit payment for the full amount' do
          expect(subject).to be_success

          expect(order.reload.payments.count).to eq 1
          expect(order.payments.first).to be_store_credit
          expect(order.payments.first.amount).to eq order_total

          expect(order.updater).to have_received(:run_hooks)
        end
      end

      context 'with store credit amount specified' do
        let(:requested_amount) { 300.0 }

        it 'creates a store credit payment for the specified amount' do
          expect(subject).to be_success

          expect(order.reload.payments.count).to eq 1
          expect(order.payments.first).to be_store_credit
          expect(order.payments.first.amount).to eq requested_amount

          expect(order.updater).to have_received(:run_hooks)
        end
      end
    end

    context 'the available store credit is not enough to pay for the entire order' do
      let(:expected_cc_total) { 100.0 }
      let(:store_credit_total) { order_total - expected_cc_total }
      let(:store_credit) { create(:store_credit, amount: store_credit_total, store: store) }
      let(:order) { create(:order, user: store_credit.user, total: order_total, store: store) }
      let!(:store_credit_2) { create(:store_credit, amount: 10) }

      before do
        # callbacks recalculate total based on line items
        # this ensures the total is what we expect
        order.update_column(:total, order_total)
      end

      it 'creates a store credit payment for the available amount' do
        expect(subject).to be_success

        expect(order.reload.payments.count).to eq 1
        expect(order.payments.first).to be_store_credit
        expect(order.payments.first.amount).to eq store_credit_total

        expect(order.updater).to have_received(:run_hooks)
      end
    end

    context 'there are multiple store credits' do
      let(:amount_difference) { 100 }
      let!(:primary_store_credit) { create(:store_credit, amount: (order_total - amount_difference), store: store) }
      let!(:secondary_store_credit) do
        create(:store_credit, amount: order_total, user: primary_store_credit.user,
                credit_type: create(:secondary_credit_type), store: store)
      end
      let(:order) { create(:order, user: primary_store_credit.user, total: order_total, store: store) }

      before do
        Timecop.scale(3600)
      end

      after { Timecop.return }

      it 'uses the primary store credit type over the secondary' do
        expect(subject).to be_success

        primary_payment = order.reload.payments.first
        secondary_payment = order.payments.last

        expect(order.payments.size).to eq 2
        expect(primary_payment.source).to eq primary_store_credit
        expect(secondary_payment.source).to eq secondary_store_credit
        expect(primary_payment.amount).to eq(order_total - amount_difference)
        expect(secondary_payment.amount).to eq(amount_difference)

        expect(order.updater).to have_received(:run_hooks)
      end
    end
  end
end
