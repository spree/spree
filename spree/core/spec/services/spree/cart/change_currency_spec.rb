require 'spec_helper'

module Spree
  describe Cart::ChangeCurrency do
    subject { described_class.call(order: order, new_currency: new_currency) }

    let(:order) { create(:order_with_line_items, store: store, currency: 'USD') }
    let(:store) { @default_store }

    before do
      allow(store).to receive(:supported_currencies).and_return('USD,EUR,GBP')
    end

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

    context 'when there are items that are not available in the new currency' do
      let(:new_currency) { 'EUR' }

      it 'removes them from the Cart' do
        expect(order.line_items).not_to be_empty
        expect(subject).to be_success
        expect(Spree::Order.find(order.id).line_items).to be_empty
      end
    end
  end
end
