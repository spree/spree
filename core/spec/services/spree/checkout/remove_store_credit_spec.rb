require 'spec_helper'

describe Spree::Checkout::RemoveStoreCredit, type: :service do
  describe '#call' do
    subject { described_class.call(order: order) }

    let(:order_total) { 500.00 }
    let(:order) { create(:order, user: store_credit.user, total: order_total) }

    context 'when order is not complete' do
      let(:store_credit) { create(:store_credit, amount: order_total - 1) }

      before do
        create(:store_credit_payment_method)
        Spree::Checkout::AddStoreCredit.call(order: order)
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
end
