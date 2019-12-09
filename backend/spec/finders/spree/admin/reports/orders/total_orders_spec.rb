require 'spec_helper'

describe Spree::Admin::Reports::Orders::TotalOrders do
  subject do
    described_class.new(
      completed_at_min: completed_at_min,
      completed_at_max: completed_at_max,
      group_by: group_by
    )
  end

  let(:completed_at_min) { nil }
  let(:completed_at_max) { nil }
  let(:group_by) { nil }

  context 'when the date range is not present' do
    it 'returns a report from last 7 days' do
      create(:completed_order_with_totals).update!(completed_at: '2019-02-13')
      create(:completed_order_with_totals).update!(completed_at: '2019-02-13')
      create(:completed_order_with_totals).update!(completed_at: '2019-02-14')

      Timecop.freeze(2019, 02, 20) do
        array = subject.call

        expect(array).to eq [
          ['2019-02-13', 2],
          ['2019-02-14', 1],
          ['2019-02-15', 0],
          ['2019-02-16', 0],
          ['2019-02-17', 0],
          ['2019-02-18', 0],
          ['2019-02-19', 0],
          ['2019-02-20', 0]
        ]
      end
    end
  end

  context 'when the date rage is valid' do
    context 'when group_by is set to year' do
      let(:completed_at_min) { '2016-01-01' }
      let(:completed_at_max) { '2019-01-01' }
      let(:group_by) { :year }

      it 'returns average totals grouped by year' do
        create(:completed_order_with_totals).update!(completed_at: '2016-12-12')
        create(:completed_order_with_totals).update!(completed_at: '2018-12-12')
        create(:completed_order_with_totals).update!(completed_at: '2018-12-12')

        array = subject.call

        expect(array).to eq [['2016', 1], ['2017', 0], ['2018', 2], ['2019', 0]]
      end
    end

    context 'when group_by is set to month' do
      let(:completed_at_min) { '2017-11-03' }
      let(:completed_at_max) { '2018-02-22' }
      let(:group_by) { :month }

      it 'returns summed totals grouped by month' do
        create(:completed_order_with_totals).update!(completed_at: '2017-12-12')
        create(:completed_order_with_totals).update!(completed_at: '2017-12-12')
        create(:completed_order_with_totals).update!(completed_at: '2018-01-01')

        array = subject.call

        expect(array).to eq [['2017-11', 0], ['2017-12', 2], ['2018-01', 1], ['2018-02', 0]]
      end
    end

    context 'when group_by is set to day' do
      let(:completed_at_min) { '2017-12-30' }
      let(:completed_at_max) { '2018-01-2' }
      let(:group_by) { :day }

      it 'returns summed totals grouped by day' do
        create(:completed_order_with_totals).update!(completed_at: '2017-12-30')
        create(:completed_order_with_totals).update!(completed_at: '2017-12-30')
        create(:completed_order_with_totals).update!(completed_at: '2018-01-02')

        array = subject.call

        expect(array).to eq [['2017-12-30', 2], ['2017-12-31', 0], ['2018-01-01', 0], ['2018-01-02', 1]]
      end
    end
  end
end
