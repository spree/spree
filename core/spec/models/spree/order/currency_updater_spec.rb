require 'spec_helper'

describe Spree::Order, type: :model do
  context 'CurrencyUpdater' do
    context 'when changing order currency' do
      let!(:line_item) { create(:line_item) }
      let!(:euro_price) { create(:price, variant: line_item.variant, amount: 8, currency: 'EUR') }

      context '#homogenize_line_item_currencies' do
        it 'succeeds without error' do
          expect { line_item.order.update_attributes!(currency: 'EUR') }.not_to raise_error
        end

        it 'changes the line_item currencies' do
          expect { line_item.order.update_attributes!(currency: 'EUR') }.to change { line_item.reload.currency }.from('USD').to('EUR')
        end

        it 'changes the line_item amounts' do
          expect { line_item.order.update_attributes!(currency: 'EUR') }.to change { line_item.reload.amount }.to(8)
        end

        it 'fails to change the order currency when no prices are available in that currency' do
          expect { line_item.order.update_attributes!(currency: 'GBP') }.to raise_error("no GBP price found for #{line_item.product.name} (#{line_item.variant.sku})")
        end

        it 'calculates the item total in the order.currency' do
          expect { line_item.order.update_attributes!(currency: 'EUR') }.to change { line_item.order.item_total }.to(8)
        end
      end
    end
  end
end
