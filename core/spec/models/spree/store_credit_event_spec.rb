require 'spec_helper'

describe 'StoreCreditEvent' do
  describe '#display_amount' do
    subject { create(:store_credit_auth_event, amount: event_amount) }

    let(:event_amount) { 120.0 }

    it 'returns a Spree::Money instance' do
      expect(subject.display_amount).to be_instance_of(Spree::Money)
    end

    it 'uses the events amount attribute' do
      expect(subject.display_amount).to eq Spree::Money.new(event_amount, currency: subject.currency)
    end
  end

  describe '#display_user_total_amount' do
    subject { create(:store_credit_auth_event, user_total_amount: user_total_amount) }

    let(:user_total_amount) { 300.0 }

    it 'returns a Spree::Money instance' do
      expect(subject.display_user_total_amount).to be_instance_of(Spree::Money)
    end

    it 'uses the events user_total_amount attribute' do
      amount = Spree::Money.new(user_total_amount, currency: subject.currency)
      expect(subject.display_user_total_amount).to eq amount
    end
  end

  describe '#display_action' do
    subject { create(:store_credit_auth_event, action: action) }

    context 'capture event' do
      let(:action) { Spree::StoreCredit::CAPTURE_ACTION }

      it 'returns used' do
        expect(subject.display_action).to eq Spree.t('store_credit.captured')
      end
    end

    context 'authorize event' do
      let(:action) { Spree::StoreCredit::AUTHORIZE_ACTION }

      it 'returns authorized' do
        expect(subject.display_action).to eq Spree.t('store_credit.authorized')
      end
    end

    context 'allocation event' do
      let(:action) { Spree::StoreCredit::ALLOCATION_ACTION }

      it 'returns added' do
        expect(subject.display_action).to eq Spree.t('store_credit.allocated')
      end
    end

    context 'void event' do
      let(:action) { Spree::StoreCredit::VOID_ACTION }

      it 'returns credit' do
        expect(subject.display_action).to eq Spree.t('store_credit.credit')
      end
    end

    context 'credit event' do
      let(:action) { Spree::StoreCredit::CREDIT_ACTION }

      it 'returns credit' do
        expect(subject.display_action).to eq Spree.t('store_credit.credit')
      end
    end
  end

  describe '#order' do
    let(:store) { Spree::Store.default }
    let(:store_credit) { create(:store_credit, store: store) }

    context 'there is no associated payment with the event' do
      subject { create(:store_credit_auth_event, store_credit: store_credit) }

      it 'returns nil' do
        expect(subject.order).to be_nil
      end
    end

    context 'there is an associated payment with the event' do
      subject do
        create(:store_credit_auth_event, action: Spree::StoreCredit::CAPTURE_ACTION,
                                         authorization_code: authorization_code,
                                         store_credit: store_credit)
      end

      let(:authorization_code) { '1-SC-TEST' }
      let(:order) { create(:order, store: store, total: 100) }
      let!(:payment) { create(:store_credit_payment, order: order, response_code: authorization_code) }

      it 'returns the order associated with the payment' do
        expect(subject.order).to eq order
      end
    end
  end

  describe '#store' do
    let(:store) { Spree::Store.default }
    let(:store_credit) { create(:store_credit, store: store) }

    subject { build(:store_credit_auth_event, store_credit: store_credit) }

    it { expect(subject.store).to eq(store) }
  end
end
