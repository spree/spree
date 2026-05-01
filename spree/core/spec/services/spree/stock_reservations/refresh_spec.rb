require 'spec_helper'

describe Spree::StockReservations::Refresh do
  let(:order) { create(:order_with_line_items, line_items_count: 1) }
  let(:variant) { order.line_items.first.variant }
  let!(:stock_item) do
    si = variant.stock_items.first
    si.update!(backorderable: false)
    si.set_count_on_hand(10)
    si
  end

  before { Spree::Config[:stock_reservations_enabled] = true }

  context 'when the order is in a checkout state' do
    before { order.update_column(:state, 'delivery') }

    it 'creates a reservation' do
      expect { described_class.call(order: order) }
        .to change { Spree::StockReservation.where(order_id: order.id).count }.from(0).to(1)
    end
  end

  %w[cart complete canceled].each do |state|
    context "when the order is in `#{state}`" do
      before { order.update_column(:state, state) }

      it 'is a no-op' do
        expect { described_class.call(order: order) }
          .not_to change { Spree::StockReservation.where(order_id: order.id).count }
      end
    end
  end

  it 'returns success' do
    order.update_column(:state, 'cart')
    expect(described_class.call(order: order)).to be_success
  end
end
