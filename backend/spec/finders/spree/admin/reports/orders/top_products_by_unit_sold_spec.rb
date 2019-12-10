
require 'spec_helper'

describe Spree::Admin::Reports::Orders::TopProductsByUnitSold do
  subject do
    described_class.new(
      completed_at_min: completed_at_min,
      completed_at_max: completed_at_max
    )
  end

  let(:completed_at_min) { nil }
  let(:completed_at_max) { nil }

  let!(:order1) { create(:completed_order_with_totals) }
  let!(:order2) { create(:completed_order_with_totals) }
  let!(:order3) { create(:completed_order_with_totals) }

  let(:product1) { create(:product) }
  let(:product2) { create(:product) }

  let(:variant1) { create(:variant, product: product1)}

  before do
    order1.line_items.first.update(variant: product1.master)
    order2.line_items.first.update(variant: variant1)
    order3.line_items.first.update(variant: product2.master)
  end

  context 'when the date range is not present' do
    it 'returns a report from last 7 days' do
      order1.update!(completed_at: '2019-01-13')
      order2.update!(completed_at: '2019-02-13')
      order3.update!(completed_at: '2019-02-14')

      Timecop.freeze(2019, 02, 20) do
        array = subject.call

        expect(array).to eq [
          [variant1.sku, 1],
          [product2.master.sku, 1]
        ]
      end
    end
  end

  context 'when the date range is valid' do
    context 'when date range includes all the orders' do
      let(:completed_at_min) { '2016-01-01' }
      let(:completed_at_max) { '2019-01-01' }

      it 'returns top product grouped by product SKU' do
        order1.update!(completed_at: '2016-12-12')
        order2.update!(completed_at: '2018-12-12')
        order3.update!(completed_at: '2018-12-12')

        array = subject.call

        expect(array).to eq [
          [product1.master.sku, 1],
          [variant1.sku, 1],
          [product2.master.sku, 1]
        ]
      end
    end

    context 'when date range includes only part of all orders' do
      let(:completed_at_min) { '2017-01-01' }
      let(:completed_at_max) { '2019-01-01' }

      it 'returns top products grouped by product SKU' do
        order1.update!(completed_at: '2016-12-12')
        order2.update!(completed_at: '2018-12-12')
        order3.update!(completed_at: '2018-12-12')

        array = subject.call

        expect(array).to eq [
          [variant1.sku, 1],
          [product2.master.sku, 1]
        ]
      end
    end
  end
end
