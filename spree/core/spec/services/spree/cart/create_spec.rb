require 'spec_helper'

module Spree
  describe Cart::Create do
    subject { described_class }

    let(:user) { create :user }
    let(:store) { create :store, default_currency: 'EUR' }
    let(:currency) { 'USD' }
    let(:public_metadata) { { prop1: 2 } }
    let(:private_metadata) { { prop2: 'val2' } }
    let(:expected) { Order.first }

    context 'create an order' do
      let(:execute) { subject.call user: user, store: store, currency: currency, public_metadata: public_metadata, private_metadata: private_metadata }
      let(:value) { execute.value }

      it do
        expect { execute }.to change(Order, :count)
        expect(execute).to be_success
        expect(value).to eq expected
        expect(expected.number).to be_present
      end
    end

    context 'create an order with store currency' do
      let(:order_params) { { store: store, currency: nil } }
      let(:execute) { subject.call user: user, store: store, currency: currency, order_params: order_params }
      let(:value) { execute.value }

      it do
        expect { execute }.to change(Order, :count)
        expect(execute).to be_success
        expect(value).to eq expected
        expect(expected.user).to eq user
        expect(expected.store).to eq store
        expect(expected.currency).to eq 'EUR'
        expect(expected.number).to be_present
      end
    end

    context 'create an order with locale' do
      let(:execute) { subject.call user: user, store: store, currency: currency, locale: 'fr' }
      let(:value) { execute.value }

      before do
        allow(store).to receive(:supported_locales_list).and_return(['en', 'fr'])
      end

      it do
        expect { execute }.to change(Order, :count)
        expect(execute).to be_success
        expect(value.locale).to eq('fr')
      end
    end

    context 'create an order with default locale from Spree::Current' do
      let(:execute) { subject.call user: user, store: store, currency: currency }
      let(:value) { execute.value }

      before do
        allow(Spree::Current).to receive(:locale).and_return('en')
      end

      it do
        expect { execute }.to change(Order, :count)
        expect(execute).to be_success
        expect(value.locale).to eq('en')
      end
    end

    context 'returns failure when no store is passed' do
      let!(:default_store) { create :store, default: true }
      let(:execute) { subject.call user: user, store: nil, currency: nil }
      let(:value) { execute.value }

      it do
        expect { execute }.not_to change(Order, :count)
        expect(execute).to be_failure
      end
    end
  end
end
