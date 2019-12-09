require 'spec_helper'

describe Spree::Admin::Reports::Orders::TotalSales do
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
    let(:completed_at_min) { '2019-12-12' }

    it 'raises an error' do
      expect { subject.call }.to raise_error 'Date range is invalid.'
    end
  end

  context 'when the date range is invalid' do
    let(:completed_at_min) { '2019-12-12' }
    let(:completed_at_max) { '2019' }

    it 'raises an error' do
      expect { subject.call }.to raise_error 'Date range is invalid.'
    end
  end

  context 'when the date rage is valid' do
    context 'when group_by is set to year' do
      let(:completed_at_min) { '2016-01-01' }
      let(:completed_at_max) { '2019-01-01' }
      let(:group_by) { :year }

      it 'returns average totals grouped by year' do
        create(:completed_order_with_totals).update!(completed_at: '2016-12-12', total: 300)
        create(:completed_order_with_totals).update!(completed_at: '2018-12-12', total: 100)
        create(:completed_order_with_totals).update!(completed_at: '2018-12-12', total: 300)

        array = subject.call

        expect(array).to eq [['2016', 300], ['2017', 0], ['2018', 400], ['2019', 0]]
      end
    end

    context 'when group_by is set to month' do
      let(:completed_at_min) { '2017-11-03' }
      let(:completed_at_max) { '2018-02-22' }
      let(:group_by) { :month }

      it 'returns summed totals grouped by month' do
        create(:completed_order_with_totals).update!(completed_at: '2017-12-12', total: 100)
        create(:completed_order_with_totals).update!(completed_at: '2017-12-12', total: 200)
        create(:completed_order_with_totals).update!(completed_at: '2018-01-01', total: 300)

        array = subject.call

        expect(array).to eq [['2017-11', 0], ['2017-12', 300], ['2018-01', 300], ['2018-02', 0]]
      end
    end

    context 'when group_by is set to day' do
      let(:completed_at_min) { '2017-12-30' }
      let(:completed_at_max) { '2018-01-2' }
      let(:group_by) { :day }

      it 'returns summed totals grouped by day' do
        create(:completed_order_with_totals).update!(completed_at: '2017-12-30', total: 200)
        create(:completed_order_with_totals).update!(completed_at: '2017-12-30', total: 400)
        create(:completed_order_with_totals).update!(completed_at: '2018-01-02', total: 600)

        array = subject.call

        expect(array).to eq [['2017-12-30', 600], ['2017-12-31', 0], ['2018-01-01', 0], ['2018-01-02', 600]]
      end
    end
  end
end
