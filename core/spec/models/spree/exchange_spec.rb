require 'spec_helper'

module Spree
  describe Exchange, type: :model do
    let(:order) { Spree::Order.new }

    let(:return_item_1) { build(:exchange_return_item) }
    let(:return_item_2) { build(:exchange_return_item) }
    let(:return_items) { [return_item_1, return_item_2] }
    let(:exchange) { Exchange.new(order, return_items) }

    describe '#description' do
      before do
        allow(return_item_1).to receive(:variant) { double(options_text: 'foo') }
        allow(return_item_1).to receive(:exchange_variant) { double(options_text: 'bar') }
        allow(return_item_2).to receive(:variant) { double(options_text: 'baz') }
        allow(return_item_2).to receive(:exchange_variant) { double(options_text: 'qux') }
      end

      it "describes the return items' change in options" do
        expect(exchange.description).to match(/foo => bar/)
        expect(exchange.description).to match(/baz => qux/)
      end
    end

    describe '#display_amount' do
      it 'is the total amount of all return items' do
        expect(exchange.display_amount).to eq Spree::Money.new(0.0)
      end
    end

    describe '#perform!' do
      subject { exchange.perform! }

      let(:return_item) { create(:exchange_return_item) }
      let(:return_items) { [return_item] }
      let(:order) { return_item.return_authorization.order }

      before { return_item.exchange_variant.stock_items.first.adjust_count_on_hand(20) }

      it 'creates shipments for the order with the return items exchange inventory units' do
        expect { subject }.to change { order.shipments.count }.by(1)
        new_shipment = order.shipments.last
        expect(new_shipment).to be_ready
        new_inventory_units = new_shipment.inventory_units
        expect(new_inventory_units.count).to eq 1
        expect(new_inventory_units.first.original_return_item).to eq return_item
        expect(new_inventory_units.first.line_item).to eq return_item.inventory_unit.line_item
      end

      context 'when it cannot create shipments for all items' do
        before do
          StockItem.where(variant_id: return_item.exchange_variant_id).destroy_all
        end

        it 'raises an UnableToCreateShipments error' do
          expect do
            subject
          end.to raise_error(Spree::Exchange::UnableToCreateShipments)
        end
      end
    end

    describe '#to_key' do # for dom_id
      it { expect(Exchange.new(nil, nil).to_key).to be_nil }
    end

    describe '.param_key' do # for dom_id
      it { expect(Exchange.param_key).to eq 'spree_exchange' }
    end

    describe '.model_name' do # for dom_id
      it { expect(Exchange.model_name).to eq Spree::Exchange }
    end
  end
end
