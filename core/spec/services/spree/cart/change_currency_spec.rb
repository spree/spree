require 'spec_helper'

module Spree
  describe Cart::ChangeCurrency do
    subject { described_class.call(order: order, new_currency: new_currency) }

    let(:order) { create(:order_with_line_items, store: store, currency: 'USD') }
    let(:store) { create(:store, supported_currencies: 'USD,EUR,GBP') }

    context 'when switching to a supported currency' do
      let(:new_currency) { 'EUR' }

      context 'when product has a price in given currency' do
        let!(:price) { create(:price, currency: 'EUR', variant: order.line_items.first.variant)}

        it 'changes order and line items currency' do
          expect(subject).to be_success
          order.reload
          expect(order.currency).to eq('EUR')
          expect(order.line_items.first.currency).to eq('EUR')
        end

        it 'removes the shipment and restarts the checkout flow' do
          expect(subject).to be_success
          order.reload
          expect(order.shipments).to be_empty
          expect(order.state).to eq('address')
        end

        context 'when the order has no shipment' do
          let(:order) { create(:order_with_totals, store: store, currency: 'USD', state: 'delivery') }

          it 'does not restart the checkout flow' do
            expect(subject).to be_success
            order.reload
            expect(order.state).to eq('delivery')
          end
        end
      end

      context 'when product does not have a price in given currency' do
        it 'returns failure' do
          expect(subject).to be_failure
          order.reload
          expect(order.currency).to eq('USD')
          expect(order.line_items.first.currency).to eq('USD')
        end
      end
    end

    context 'when switching to an unsupported currency' do
      let(:new_currency) { 'XOF' }

      it 'returns failure' do
        expect(subject).to be_failure
        order.reload
        expect(order.currency).to eq('USD')
        expect(order.line_items.first.currency).to eq('USD')
      end
    end
  end
end
