require 'spec_helper'

describe Spree::Admin::Reports::AverageOrderValues::JsonSerializer do
  describe '#call' do
    subject { described_class.new.call(data) }

    let(:data) do
      [
        ['2019-11-30', 300],
        ['2019-11-29', 200]
      ]
    end

    it 'serializes data to csv' do
      expect(subject.as_json).to eq(
        'labels' => ['2019-11-30', '2019-11-29'],
        'data'   => [300, 200]
      )
    end
  end
end
