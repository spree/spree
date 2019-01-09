require 'spec_helper'

module Spree
  describe Cart::Create do
    subject { described_class }

    let(:user) { create :user }
    let(:store) { create :store }
    let(:currency) { 'USD' }
    let(:expected) { Order.first }

    context 'create an order' do
      let(:execute) { subject.call user: user, store: store, currency: currency }
      let(:value) { execute.value }

      it do
        expect { execute }.to change(Order, :count)
        expect(execute).to be_success
        expect(value).to eq expected
        expect(expected.number).to be_present
      end
    end

    context 'create an order with store in params' do
      let(:store_2) { create :store }
      let(:order_params) { { store: store_2, currency: 'XVII' } }
      let(:execute) { subject.call user: user, store: store, currency: currency, order_params: order_params }
      let(:value) { execute.value }

      it do
        expect { execute }.to change(Order, :count)
        expect(execute).to be_success
        expect(value).to eq expected
        expect(expected.user).to eq user
        expect(expected.store).to eq store_2
        expect(expected.currency).to eq 'XVII'
        expect(expected.number).to be_present
      end
    end

    context 'create an order when no store and currency pass in params' do
      let!(:default_store) { create :store, default: true }
      let(:execute) { subject.call user: user, store: nil, currency: nil }
      let(:value) { execute.value }

      it do
        expect { execute }.to change(Order, :count)
        expect(execute).to be_success
        expect(value).to eq expected
        expect(expected.currency).to eq Spree::Config[:currency]
        expect(expected.store).to eq Spree::Store.default
        expect(expected.number).to be_present
      end
    end
  end
end
