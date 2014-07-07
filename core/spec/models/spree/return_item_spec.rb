require 'spec_helper'

describe Spree::ReturnItem do
  describe '#receive!' do
    let(:return_item) {
      create(:return_item, {
        return_authorization: return_authorization,
        inventory_unit: inventory_unit,
      })
    }

    let(:order) { create(:shipped_order, line_items_count: 1) }
    let(:return_authorization) { create(:return_authorization, order: order, stock_location: stock_location) }
    let(:stock_location) { create(:stock_location) }
    let(:inventory_unit) { order.line_items.first.inventory_units.first }
    let(:stock_item) { stock_location.stock_items.find_by(variant_id: inventory_unit.variant_id) }
    let(:now) { Time.now }

    subject { return_item.receive! }

    it 'updates received_at' do
      Timecop.freeze(now) { subject }
      expect(return_item.received_at).to eq now
    end

    it 'returns the inventory unit' do
      subject
      expect(inventory_unit.reload.state).to eq 'returned'
    end

    context 'with a stock location' do
      it 'increases the count on hand' do
        expect { subject }.to change { stock_item.reload.count_on_hand }.by(1)
      end

      context 'when variant does not track inventory' do
        before do
          inventory_unit.variant.update_attributes!(track_inventory: false)
        end

        it 'does not increase the count on hand' do
          expect { subject }.to_not change { stock_item.reload.count_on_hand }
        end
      end
    end

    context 'without a stock location' do
      let(:stock_location) { nil }

      it 'still works' do
        expect { subject }.to_not raise_error
      end
    end
  end
end
