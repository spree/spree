require 'spec_helper'

RSpec.describe Spree::GiftCards::Apply do
  subject { described_class.call(gift_card: gift_card, order: order) }

  let(:store) { Spree::Store.default }
  let(:order) { create(:order, store: store) }

  let(:gift_card) { create(:gift_card, amount: 50, store: store) }

  let(:store_credit_payment) { order.payments.store_credits.last }
  let(:store_credit) { store_credit_payment.source }

  before do
    order.update_column(:total, 30)
    order.update_column(:shipment_total, 10)
  end

  it 'applies the gift card to an order' do
    expect { subject }.to change { Spree::StoreCredit.count }.by(1)
    expect(subject).to be_success

    expect(order.reload.gift_card).to eq(gift_card)
    expect(order.gift_card_total).to eq(30)

    expect(gift_card.reload.amount_remaining).to eq(20)

    expect(store_credit_payment).to be_present
    expect(store_credit_payment).to be_checkout
    expect(store_credit_payment.source).to eq(gift_card.store_credits.last)
    expect(store_credit_payment.amount).to eq(30)

    expect(store_credit.amount).to eq(30)
    expect(store_credit.store).to eq(Spree::Store.default)
    expect(store_credit.originator).to eq(gift_card)
  end

  context 'when the order has applied store credit' do
    let!(:store_credit_payment_method) { create(:store_credit_payment_method, stores: [store]) }
    let!(:store_credit) { create(:store_credit, user: order.user, amount: 10, store: store) }

    before do
      order.add_store_credit_payments
    end

    it 'responds with an error' do
      expect { subject }.to_not change(Spree::StoreCredit, :count)

      expect(subject).to be_failure
      expect(subject.value).to eq(:gift_card_using_store_credit_error)

      expect(order.reload.gift_card).to eq(nil)
      expect(order.total_applied_store_credit).to eq(10)
      expect(order.payments.store_credits.last.source.originator).to eq(nil)
    end
  end

  context 'when the gift card has no amount remaining' do
    before { gift_card.update!(amount_used: gift_card.amount) }

    it 'responds with an error' do
      expect { subject }.to_not change(Spree::StoreCredit, :count)

      expect(subject).to be_failure
      expect(subject.value).to eq(:gift_card_no_amount_remaining)

      expect(order.reload.gift_card).to eq(nil)
    end
  end
end
