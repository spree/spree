shared_examples_for 'an adjustment source' do
  subject(:source) { described_class.create }

  before do
    allow(Spree::Adjustable::AdjustmentsUpdater).to receive(:update)
    order.adjustments.create(order: order, amount: 10, label: 'Adjustment', source: source)
  end

  describe '#destroy' do
    before { source.destroy }

    context 'when order incomplete' do
      let(:order) { create(:order_with_line_items) }

      it { expect(order.adjustments.count).to eq(0) }
    end

    context 'when order is complete' do
      let(:order) { create(:completed_order_with_totals) }

      it { expect(order.adjustments.count).to eq(1) }
      it { expect(order.adjustments.reload.first.source).to be_nil }
    end
  end
end
