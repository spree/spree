shared_examples_for 'an adjustment source' do
  subject(:source) do
    if defined?(promotion) && described_class.reflect_on_association(:promotion)
      described_class.create!(promotion: promotion)
    else
      described_class.create
    end
  end

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
