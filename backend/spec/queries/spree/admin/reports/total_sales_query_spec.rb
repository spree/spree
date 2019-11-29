require 'spec_helper'

describe Spree::Admin::Reports::TotalSalesQuery do
  let!(:order1) { create(:completed_order_with_totals) }
  let!(:order2) { create(:completed_order_with_totals) }
  let!(:order3) { create(:completed_order_with_totals) }
  let!(:order4) { create(:completed_order_with_totals) }
  let!(:order5) { create(:completed_order_with_totals) }

  before do
    order1.update(completed_at: '2019-11-29', total: 100)
    order2.update(completed_at: '2019-11-29', total: 200)
    order3.update(completed_at: '2019-10-29', total: 350)
    order4.update(completed_at: '2019-10-28', total: 360)
    order5.update(completed_at: '2018-11-29', total: 400)
  end

  let(:group_by) { nil }
  let(:completed_at_min) { nil }
  let(:completed_at_max) { nil }

  describe '#call' do
    subject do
      described_class.new.call(
        group_by: group_by,
        completed_at_min: completed_at_min,
        completed_at_max: completed_at_max
      )
    end

    context 'when no group_by param is present' do
      let(:group_by) { nil }

      it 'groups by day' do
        expect(subject).to eq [
          ['2018-11-29', 400],
          ['2019-10-28', 360],
          ['2019-10-29', 350],
          ['2019-11-29', 300]
        ]
      end
    end

    context 'when group_by param is set to month' do
      let(:group_by) { 'month' }

      it 'groups by month' do
        expect(subject).to eq [
          ['2018-11', 400],
          ['2019-10', 710],
          ['2019-11', 300]
        ]
      end
    end

    context 'when group_by param is set to year' do
      let(:group_by) { 'year' }

      it 'groups by year' do
        expect(subject).to eq [
          ['2018', 400],
          ['2019', 1010]
        ]
      end
    end

    context 'when completed_at_min is present' do
      let(:completed_at_min) { '2019-11-20' }

      it 'returns results for orders older than given date' do
        expect(subject).to match_array([
          ['2019-11-29', 300]
        ])
      end
    end

    context 'when completed_at_max is present' do
      let(:completed_at_max) { '2019-11-20' }

      it 'returns results for orders younger than given date' do
        expect(subject).to match_array([
          ['2019-10-28', 360],
          ['2019-10-29', 350],
          ['2018-11-29', 400],
        ])
      end
    end

    context 'when both completed_at_min and completed_at_max are present' do
      let(:completed_at_min) { '2019-10-28' }
      let(:completed_at_max) { '2019-11-29' }

      it 'returns results for orders younger than given date' do
        expect(subject).to match_array([
          ['2019-10-28', 360],
          ['2019-10-29', 350]
        ])
      end
    end
  end
end
