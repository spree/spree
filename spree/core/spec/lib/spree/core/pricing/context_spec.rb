require 'spec_helper'

module Spree
  module Pricing
    RSpec.describe Context do
      let(:variant) { create(:variant) }
      let(:currency) { 'USD' }
      let(:store) { @default_store }
      let(:zone) { create(:zone) }
      let(:market) { create(:market, store: store) }
      let(:user) { create(:user) }
      let(:quantity) { 5 }
      let(:date) { Time.zone.parse('2024-01-15 12:00:00') }

      after { Spree::Current.reset }

      describe '#initialize' do
        context 'with all parameters' do
          subject do
            described_class.new(
              variant: variant,
              currency: currency,
              store: store,
              zone: zone,
              market: market,
              user: user,
              quantity: quantity,
              date: date
            )
          end

          it 'sets all attributes' do
            expect(subject.variant).to eq(variant)
            expect(subject.currency).to eq(currency)
            expect(subject.store).to eq(store)
            expect(subject.zone).to eq(zone)
            expect(subject.market).to eq(market)
            expect(subject.user).to eq(user)
            expect(subject.quantity).to eq(quantity)
            expect(subject.date).to eq(date)
          end
        end

        context 'with minimal parameters' do
          subject do
            described_class.new(variant: variant, currency: currency)
          end

          it 'sets required attributes' do
            expect(subject.variant).to eq(variant)
            expect(subject.currency).to eq(currency)
          end

          it 'defaults store to Spree::Current.store' do
            expect(subject.store).to eq(Spree::Current.store)
          end

          it 'defaults zone to Spree::Current.zone' do
            expect(subject.zone).to eq(Spree::Current.zone)
          end

          it 'defaults market to Spree::Current.market' do
            expect(subject.market).to eq(Spree::Current.market)
          end

          it 'defaults user to nil' do
            expect(subject.user).to be_nil
          end

          it 'defaults quantity to nil' do
            expect(subject.quantity).to be_nil
          end

          it 'defaults date to current time' do
            Timecop.freeze do
              expect(subject.date).to be_within(1.second).of(Time.current)
            end
          end
        end

        context 'when Spree::Current.store is set' do
          let(:current_store) { create(:store) }

          before { Spree::Current.store = current_store }

          subject do
            described_class.new(variant: variant, currency: currency)
          end

          it 'uses Spree::Current.store as default' do
            expect(subject.store).to eq(current_store)
          end
        end

        context 'when Spree::Current.zone is set' do
          let(:current_zone) { create(:zone) }

          before { Spree::Current.zone = current_zone }

          subject do
            described_class.new(variant: variant, currency: currency)
          end

          it 'uses Spree::Current.zone as default' do
            expect(subject.zone).to eq(current_zone)
          end
        end

        context 'when Spree::Current.market is set' do
          let(:current_market) { create(:market) }

          before { Spree::Current.market = current_market }

          subject do
            described_class.new(variant: variant, currency: currency)
          end

          it 'uses Spree::Current.market as default' do
            expect(subject.market).to eq(current_market)
          end
        end

        context 'when market is explicitly nil' do
          before { Spree::Current.market = nil }

          subject do
            described_class.new(variant: variant, currency: currency, market: nil)
          end

          it 'falls back to Spree::Current.market' do
            expect(subject.market).to eq(Spree::Current.market)
          end
        end
      end

      describe '.from_currency' do
        subject { described_class.from_currency(variant, currency) }

        it 'creates a context with variant and currency' do
          expect(subject.variant).to eq(variant)
          expect(subject.currency).to eq(currency)
        end

        it 'uses default store' do
          expect(subject.store).to eq(Spree::Store.default)
        end
      end

      describe '.from_order' do
        let(:order) { create(:order_with_line_items, line_items_count: 1) }
        let(:order_variant) { order.line_items.first.variant }
        let(:order_quantity) { order.line_items.first.quantity }

        subject { described_class.from_order(order_variant, order) }

        it 'sets variant from parameter' do
          expect(subject.variant).to eq(order_variant)
        end

        it 'sets currency from order' do
          expect(subject.currency).to eq(order.currency)
        end

        it 'sets store from order' do
          expect(subject.store).to eq(order.store)
        end

        it 'sets user from order' do
          expect(subject.user).to eq(order.user)
        end

        it 'sets order reference' do
          expect(subject.order).to eq(order)
        end

        it 'sets quantity from line item' do
          expect(subject.quantity).to eq(order_quantity)
        end

        context 'with zone from order tax_zone' do
          let(:tax_zone) { create(:zone) }

          before do
            allow(order).to receive(:tax_zone).and_return(tax_zone)
          end

          it 'sets zone from order tax_zone' do
            expect(subject.zone).to eq(tax_zone)
          end
        end

        context 'when order has no tax zone' do
          let!(:default_tax_zone) { create(:zone, default_tax: true) }

          before do
            allow(order).to receive(:tax_zone).and_return(nil)
          end

          it 'falls back to default tax zone' do
            expect(subject.zone).to eq(default_tax_zone)
          end
        end

        context 'with explicit quantity parameter' do
          subject { described_class.from_order(order_variant, order, quantity: 10) }

          it 'uses the provided quantity' do
            expect(subject.quantity).to eq(10)
          end
        end

        context 'when variant is not in order' do
          let(:other_variant) { create(:variant) }

          subject { described_class.from_order(other_variant, order) }

          it 'sets quantity to nil' do
            expect(subject.quantity).to be_nil
          end
        end
      end

      describe '#cache_key' do
        context 'with all attributes' do
          let(:specific_date) { Time.zone.parse('2024-01-15 12:00:00') }

          subject do
            described_class.new(
              variant: variant,
              currency: currency,
              store: store,
              zone: zone,
              market: market,
              user: user,
              quantity: quantity,
              date: specific_date
            )
          end

          it 'generates a cache key with all components' do
            expected_key = [
              'spree',
              'pricing',
              variant.id,
              currency,
              store.id,
              zone.id,
              market.id,
              user.id,
              quantity,
              specific_date.to_i
            ].join('/')

            expect(subject.cache_key).to eq(expected_key)
          end
        end

        context 'with minimal attributes' do
          subject do
            described_class.new(variant: variant, currency: currency)
          end

          it 'generates a cache key with default values from Spree::Current' do
            Timecop.freeze do
              expected_parts = [
                'spree',
                'pricing',
                variant.id,
                currency,
                Spree::Current.store.id
              ]
              expected_parts << Spree::Current.zone.id if Spree::Current.zone
              expected_parts << Spree::Current.market.id if Spree::Current.market
              expected_parts << Time.current.to_i

              expect(subject.cache_key).to eq(expected_parts.join('/'))
            end
          end
        end

        context 'with some optional attributes' do
          subject do
            described_class.new(
              variant: variant,
              currency: currency,
              user: user,
              quantity: quantity
            )
          end

          it 'includes present optional attributes in correct order' do
            Timecop.freeze do
              expected_parts = [
                'spree',
                'pricing',
                variant.id,
                currency,
                Spree::Current.store.id
              ]
              expected_parts << Spree::Current.zone.id if Spree::Current.zone
              expected_parts << Spree::Current.market.id if Spree::Current.market
              expected_parts << user.id
              expected_parts << quantity
              expected_parts << Time.current.to_i

              expect(subject.cache_key).to eq(expected_parts.join('/'))
            end
          end
        end
      end
    end
  end
end
