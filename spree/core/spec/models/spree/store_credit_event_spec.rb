require 'spec_helper'

describe 'StoreCreditEvent' do
  describe '#display_amount' do
    subject { create(:store_credit_auth_event, amount: event_amount) }

    let(:event_amount) { 120.0 }

    it 'uses the events amount attribute' do
      expect(subject.display_amount).to eq Spree::Money.new(event_amount, currency: subject.currency)
    end
  end

  describe '#display_user_total_amount' do
    subject { create(:store_credit_auth_event, user_total_amount: user_total_amount) }

    let(:user_total_amount) { 300.0 }

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
        expect(subject.display_action).to eq I18n.t('spree.store_credit.captured')
      end
    end

    context 'authorize event' do
      let(:action) { Spree::StoreCredit::AUTHORIZE_ACTION }

      it 'returns authorized' do
        expect(subject.display_action).to eq I18n.t('spree.store_credit.authorized')
      end
    end

    context 'allocation event' do
      let(:action) { Spree::StoreCredit::ALLOCATION_ACTION }

      it 'returns added' do
        expect(subject.display_action).to eq I18n.t('spree.store_credit.allocated')
      end
    end

    context 'void event' do
      let(:action) { Spree::StoreCredit::VOID_ACTION }

      it 'returns credit' do
        expect(subject.display_action).to eq I18n.t('spree.store_credit.credit')
      end
    end

    context 'credit event' do
      let(:action) { Spree::StoreCredit::CREDIT_ACTION }

      it 'returns credit' do
        expect(subject.display_action).to eq I18n.t('spree.store_credit.credit')
      end
    end
  end

  describe '#order' do
    let(:store) { @default_store }
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

  describe 'action predicates' do
    it 'answers true only for its own action' do
      predicates = {
        allocation?: Spree::StoreCredit::ALLOCATION_ACTION,
        credit?: Spree::StoreCredit::CREDIT_ACTION,
        captured?: Spree::StoreCredit::CAPTURE_ACTION,
        voided?: Spree::StoreCredit::VOID_ACTION,
        authorized?: Spree::StoreCredit::AUTHORIZE_ACTION
      }

      predicates.each do |predicate, own_action|
        predicates.each_value do |action|
          event = build(:store_credit_auth_event, action: action)

          expect(event.public_send(predicate)).to be(action == own_action), "#{predicate} for #{action}"
        end
      end
    end
  end
end
