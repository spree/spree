require 'spec_helper'

module Spree
  describe Carts::Create do
    subject { described_class }

    let(:user) { create :user }
    let(:store) { create :store, default_currency: 'EUR' }
    let(:currency) { 'USD' }
    let(:metadata) { { prop1: 2 } }
    let(:expected) { Order.first }

    context 'create an order' do
      let(:execute) { subject.call user: user, store: store, currency: currency, metadata: metadata }
      let(:value) { execute.value }

      it do
        expect { execute }.to change(Order, :count)
        expect(execute).to be_success
        expect(value).to eq expected
        expect(expected.number).to be_present
      end
    end

    context 'create an order with store currency' do
      let(:cart_params) { { store: store, currency: nil } }
      let(:execute) { subject.call user: user, store: store, currency: currency, cart_params: cart_params }
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

    context 'create an order with line_items' do
      let(:variant) { create(:variant) }
      let(:variant2) { create(:variant) }

      before do
        variant.stock_items.first.update!(count_on_hand: 10)
        variant2.stock_items.first.update!(count_on_hand: 10)
        store.products << variant.product unless store.products.include?(variant.product)
        store.products << variant2.product unless store.products.include?(variant2.product)
      end

      let(:line_items) do
        [
          { variant_id: variant.prefixed_id, quantity: 1 },
          { variant_id: variant2.prefixed_id, quantity: 2 }
        ]
      end

      let(:execute) { subject.call user: user, store: store, currency: currency, items: line_items }
      let(:value) { execute.value }

      it 'creates order with line items' do
        expect(execute).to be_success
        expect(value.line_items.count).to eq(2)
        expect(value.line_items.find_by(variant: variant).quantity).to eq(1)
        expect(value.line_items.find_by(variant: variant2).quantity).to eq(2)
      end
    end

    context 'create an order with line_items using default quantity' do
      let(:variant) { create(:variant) }

      before do
        variant.stock_items.first.update!(count_on_hand: 10)
        store.products << variant.product unless store.products.include?(variant.product)
      end

      let(:line_items) { [{ variant_id: variant.prefixed_id }] }
      let(:execute) { subject.call user: user, store: store, currency: currency, items: line_items }

      it 'defaults quantity to 1' do
        expect(execute).to be_success
        expect(execute.value.line_items.first.quantity).to eq(1)
      end
    end
  end
end
