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

  it 'test' do
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
end
