require 'spec_helper'

module Spree
  describe Carts::Create do
    subject { described_class }

    let(:user) { create :user }
    let(:store) { create :store, default_currency: 'EUR' }
    let(:currency) { 'USD' }
    let(:metadata) { { prop1: 2 } }
    let(:expected) { Spree::Cart.first }

    context 'create an order' do
      let(:execute) { subject.call params: { user: user, store: store, currency: currency, metadata: metadata } }
      let(:value) { execute.value }

      it do
        expect { execute }.to change(Spree::Cart, :count)
        expect(execute).to be_success
        expect(value).to eq expected
        expect(expected.token).to be_present
      end
    end

    context 'create an order with store currency' do
      let(:execute) { subject.call params: { user: user, store: store } }
      let(:value) { execute.value }

      it do
        expect { execute }.to change(Spree::Cart, :count)
        expect(execute).to be_success
        expect(value).to eq expected
        expect(expected.user).to eq user
        expect(expected.store).to eq store
        expect(expected.currency).to eq 'EUR'
        expect(expected.token).to be_present
      end
    end

    context 'create an order with locale' do
      let(:execute) { subject.call params: { user: user, store: store, currency: currency, locale: 'fr' } }
      let(:value) { execute.value }

      before do
        allow(store).to receive(:supported_locales_list).and_return(['en', 'fr'])
      end

      it do
        expect { execute }.to change(Spree::Cart, :count)
        expect(execute).to be_success
        expect(value.locale).to eq('fr')
      end
    end

    context 'create an order with default locale from Spree::Current' do
      let(:execute) { subject.call params: { user: user, store: store, currency: currency } }
      let(:value) { execute.value }

      before do
        allow(Spree::Current).to receive(:locale).and_return('en')
      end

      it do
        expect { execute }.to change(Spree::Cart, :count)
        expect(execute).to be_success
        expect(value.locale).to eq('en')
      end
    end

    context 'create an order with market from Spree::Current' do
      let(:market) { create(:market, store: store) }
      let(:execute) { subject.call params: { user: user, store: store, currency: currency } }
      let(:value) { execute.value }

      before do
        allow(Spree::Current).to receive(:market).and_return(market)
      end

      it 'sets the market from Spree::Current' do
        expect(execute).to be_success
        expect(value.market).to eq(market)
      end
    end

    context 'create an order with explicit market' do
      let(:market) { create(:market, store: store) }
      let(:execute) { subject.call params: { user: user, store: store, currency: currency, market: market } }
      let(:value) { execute.value }

      it 'uses the explicit market' do
        expect(execute).to be_success
        expect(value.market).to eq(market)
      end
    end

    context 'returns failure when no store is passed' do
      let!(:default_store) { create :store, default: true }
      let(:execute) { subject.call params: { user: user, store: nil } }
      let(:value) { execute.value }

      it do
        expect { execute }.not_to change(Spree::Cart, :count)
        expect(execute).to be_failure
      end
    end

    context 'create an order with line_items' do
      let(:variant) { create(:variant) }
      let(:variant2) { create(:variant) }

      before do
        variant.stock_levels.first.update!(count_on_hand: 10)
        variant2.stock_levels.first.update!(count_on_hand: 10)
        store.products << variant.product unless store.products.include?(variant.product)
        store.products << variant2.product unless store.products.include?(variant2.product)
      end

      let(:items) do
        [
          { variant_id: variant.prefixed_id, quantity: 1 },
          { variant_id: variant2.prefixed_id, quantity: 2 }
        ]
      end

      let(:execute) { subject.call params: { user: user, store: store, currency: currency, items: items } }
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
        variant.stock_levels.first.update!(count_on_hand: 10)
        store.products << variant.product unless store.products.include?(variant.product)
      end

      let(:items) { [{ variant_id: variant.prefixed_id }] }
      let(:execute) { subject.call params: { user: user, store: store, currency: currency, items: items } }

      it 'defaults quantity to 1' do
        expect(execute).to be_success
        expect(execute.value.line_items.first.quantity).to eq(1)
      end
    end

    # Spree::Current.channel is whichever store the request resolved, which
    # need not be the store the cart is created in.
    it 'ignores an ambient channel belonging to another store' do
      foreign_channel = create(:channel, store: create(:store))
      allow(Spree::Current).to receive(:channel).and_return(foreign_channel)

      result = subject.call(params: { store: store })

      expect(result).to be_success
      expect(result.value.channel&.store_id).to eq(store.id)
    end

    # Currency follows whichever market wins, so a channel selling only in
    # the EU cannot price its carts in the store's USD.
    it 'takes its currency from the market the channel resolves to' do
      channel = create(:channel, store: store)
      eu = create(:market, store: store, name: 'EU', currency: 'EUR', default_locale: 'en')
      channel.markets << eu

      result = subject.call(params: { store: store, channel: channel })

      expect(result).to be_success
      expect(result.value.market).to eq(eu)
      expect(result.value.currency).to eq('EUR')
    end

    it 'refuses an explicitly supplied channel from another store' do
      foreign_channel = create(:channel, store: create(:store))

      result = subject.call(params: { store: store, channel: foreign_channel })

      expect(result).to be_failure
    end

    # The ambient market follows the shopper's country and may be one the
    # channel does not sell into; forcing it past the concern's resolution
    # would make the cart fail its own validation
    # (docs/plans/6.0-channel-markets.md).
    context 'when the channel does not serve the ambient market' do
      let!(:channel) { create(:channel, store: store) }
      let!(:served) { create(:market, store: store, name: 'Served', currency: 'EUR') }

      before do
        channel.markets << served
        Spree::Current.market = store.default_market
      end

      after { Spree::Current.market = nil }

      it 'falls back to a market the channel serves' do
        result = subject.call(params: { store: store, channel: channel })

        expect(result).to be_success
        expect(channel.serves_market?(result.value.market)).to be true
      end
    end
  end
end
