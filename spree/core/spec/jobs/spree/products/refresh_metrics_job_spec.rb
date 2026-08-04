require 'spec_helper'

RSpec.describe Spree::Products::RefreshMetricsJob, type: :job do
  describe '#perform' do
    let(:store) { @default_store }
    let(:product) { create(:product, store: store) }

    subject { described_class.perform_now(product.id) }

    context 'when the product has completed orders' do
      let!(:order) { create(:completed_order_with_totals, line_items_price: 50, store: store, variants: [product.default_variant]) }

      it 'sets +units_sold_count+ and +revenue+ on the product from completed line items' do
        subject
        expect(product.reload.units_sold_count).to be > 0
        expect(product.reload.revenue).to be > 0
      end
    end

    context 'when the product has no completed orders' do
      it 'leaves the metrics at zero' do
        subject
        expect(product.reload.units_sold_count).to eq(0)
        expect(product.reload.revenue).to eq(0)
      end
    end

    context 'when product_id is invalid' do
      subject { described_class.perform_now('non-existent-id') }

      it 'is a no-op' do
        expect { subject }.not_to raise_error
      end
    end
  end
end
