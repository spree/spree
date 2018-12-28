require 'spec_helper'

describe Spree::Checkout::AddStoreCredit, type: :service do

  describe '#call' do
    subject { described_class.call(order: order) }

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

      context 'with no amount specified' do
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

      context 'with store credit amount specified' do
        let(:requested_amount) { 300.0 }

        before do
          described_class.call(order: order, amount: requested_amount)
        end

        it 'creates a store credit payment for the specified amount' do
          expect(order.payments.count).to eq 1
          expect(order.payments.first).to be_store_credit
          expect(order.payments.first.amount).to eq requested_amount
        end
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
end
