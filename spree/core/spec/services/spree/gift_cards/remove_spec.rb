require 'spec_helper'

RSpec.describe Spree::GiftCards::Remove do
  subject { described_class.call(order: order) }

  let(:order) { create(:order) }

  let(:gift_card) { create(:gift_card, amount: 50, store: Spree::Store.default) }

  let(:store_credit_payment) { order.payments.store_credits.last }
  let(:store_credit) { store_credit_payment.source }

  before do
    Spree::Config[:geocode_addresses] = false
    order.update_column(:total, 30)
    order.update_column(:shipment_total, 10)
  end

  after do
    Spree::Config[:geocode_addresses] = true
  end

  context 'for an order with the gift card applied' do
    before do
      Spree::GiftCards::Apply.call(gift_card: gift_card, order: order)
    end

    it 'removes the gift card from an order' do
      expect { subject }.to change(Spree::StoreCredit, :count).by(-1)
      expect(subject).to be_success

      expect(order.reload.gift_card).to be_nil

      expect(gift_card.reload).to be_active
      expect(gift_card.amount_remaining).to eq(50)

      expect(store_credit_payment).to be_present
      expect(store_credit_payment.state).to eq('invalid')
      expect(store_credit_payment.source).to be_deleted
    end

    it 'calls update_with_updater!' do
      expect(order).to receive(:update_with_updater!)
      subject
    end

    context 'for a completed order' do
      before { order.update_column(:completed_at, Time.current) }

      it 'responds with an error' do
        expect(subject).to be_failure
        expect(subject.value).to eq(:remove_gift_card_on_completed_order_error)
      end
    end
  end

  context 'for an order without a gift card' do
    it 'does nothing' do
      expect(subject).to be_success
    end
  end
end
