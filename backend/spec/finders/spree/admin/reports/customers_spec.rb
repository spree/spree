require 'spec_helper'

describe Spree::Admin::Reports::Customers do
  let :params do
    {
      date_from: date_from,
      date_to: date_to,
      group_by: group_by
    }
  end

  subject { described_class.new(params) }

  let(:date_from) { nil }
  let(:date_to) { nil }
  let(:group_by) { nil }

  it 'returns customer totals' do
    create_list(:user, 3, created_at: '2019-12-10')
    create_list(:user, 2, created_at: '2019-12-11')

    Timecop.freeze(2019, 12, 12) do
      expect(subject.call).to eq [
        ['2019-12-05', 0],
        ['2019-12-06', 0],
        ['2019-12-07', 0],
        ['2019-12-08', 0],
        ['2019-12-09', 0],
        ['2019-12-10', 3],
        ['2019-12-11', 2],
        ['2019-12-12', 0]
      ]
    end
  end

  context 'when the date rage is valid' do
    context 'when group_by is set to year' do
      let(:date_from) { '2016-01-01' }
      let(:date_to) { '2019-12-12' }
      let(:group_by) { :year }

      it 'returns totals grouped by year' do
        create_list(:user, 3, created_at: '2019-12-10')
        create_list(:user, 2, created_at: '2017-12-11')

        expect(subject.call).to eq [
          ['2016', 0],
          ['2017', 2],
          ['2018', 0],
          ['2019', 3]
        ]
      end
    end

    context 'when group_by is set to month' do
      let(:date_from) { '2017-11-03' }
      let(:date_to) { '2018-02-22' }
      let(:group_by) { :month }

      it 'returns totals grouped by month' do
        create_list(:user, 3, created_at: '2018-01-10')
        create_list(:user, 2, created_at: '2017-12-11')

        expect(subject.call).to eq [
          ['2017-11', 0],
          ['2017-12', 2],
          ['2018-01', 3],
          ['2018-02', 0]
        ]
      end
    end

    context 'when group_by is set to day' do
      let(:date_from) { '2017-12-30' }
      let(:date_to) { '2018-01-2' }
      let(:group_by) { :day }

      it 'returns totals grouped by day' do
        create_list(:user, 3, created_at: '2018-01-2')
        create_list(:user, 2, created_at: '2017-12-30')

        expect(subject.call).to eq [
          ['2017-12-30', 2],
          ['2017-12-31', 0],
          ['2018-01-01', 0],
          ['2018-01-02', 3]
        ]
      end
    end
  end
end
