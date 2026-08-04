require 'spec_helper'

RSpec.shared_examples 'a line item currencies host' do
  context 'when changing the record currency' do
    let!(:euro_price) { create(:price, variant: line_item.variant, amount: 8, currency: 'EUR') }

    describe '#homogenize_line_item_currencies' do
      it 'succeeds without error' do
        expect { record.update!(currency: 'EUR') }.not_to raise_error
      end

      it 'changes the line_item currencies' do
        expect { record.update!(currency: 'EUR') }.to change { line_item.reload.currency }.from('USD').to('EUR')
      end

      it 'changes the line_item amounts' do
        expect { record.update!(currency: 'EUR') }.to change { line_item.reload.amount }.to(8)
      end

      it 'calculates the item total in the record currency' do
        expect { record.update!(currency: 'EUR') }.to change { record.item_total }.to(8)
      end

      context 'when there is a price with nil amount' do
        let!(:euro_price) do
          allow(Spree::Config).to receive(:allow_empty_price_amount).and_return(true)
          create(:price, variant: line_item.variant, amount: nil, currency: 'EUR')
        end

        it "destroys the line item when we switch to that price's currency" do
          expect { record.update!(currency: 'EUR') }.to change(Spree::LineItem, :count).by(-1)
        end
      end
    end
  end
end

RSpec.describe Spree::Purchase::LineItemCurrencies do
  let(:store) { @default_store }

  context 'included in Spree::Cart' do
    let(:record) { create(:cart, store: store) }
    let!(:line_item) { create(:line_item, cart: record, order: nil) }

    it_behaves_like 'a line item currencies host'
  end

  context 'included in Spree::Order' do
    let!(:line_item) { create(:line_item) }
    let(:record) { line_item.order }

    it_behaves_like 'a line item currencies host'
  end
end
