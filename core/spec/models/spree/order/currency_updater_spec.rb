require 'spec_helper'

describe Spree::Order, type: :model do
  context 'CurrencyUpdater' do
    context 'when changing order currency' do
      let!(:line_item) { create(:line_item) }
      let!(:euro_price) { create(:price, variant: line_item.variant, amount: 8, currency: 'EUR') }

      context '#homogenize_line_item_currencies' do
        it 'succeeds without error' do
          expect { line_item.order.update!(currency: 'EUR') }.not_to raise_error
        end

        it 'changes the line_item currencies' do
          expect { line_item.order.update!(currency: 'EUR') }.to change { line_item.reload.currency }.from('USD').to('EUR')
        end

        it 'changes the line_item amounts' do
          expect { line_item.order.update!(currency: 'EUR') }.to change { line_item.reload.amount }.to(8)
        end

        it 'calculates the item total in the order.currency' do
          expect { line_item.order.update!(currency: 'EUR') }.to change { line_item.order.item_total }.to(8)
        end

        context 'when there is a price with nil amount' do
          let!(:euro_price) do
            allow(Spree::Config).to receive(:allow_empty_price_amount).and_return(true)
            create(:price, variant: line_item.variant, amount: nil, currency: 'EUR')
          end

          it 'destroys the line item when we switch to that price\'s currency' do
            expect { line_item.order.update!(currency: 'EUR') }.to change(Spree::LineItem, :count).by(-1)
          end
        end
      end
    end
  end
end
