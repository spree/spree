require 'spec_helper'

describe Spree::Admin::Reports::TotalSales::CsvSerializer do
  describe '#call' do
    subject { described_class.new.call(data) }

    let(:data) do
      [
        ['2019-11-30', 300],
        ['2019-11-29', 200]
      ]
    end

    it 'serializes data to csv' do
      expect(subject).to eq <<~HEREDOC
        date,total_sales
        2019-11-30,300
        2019-11-29,200
      HEREDOC
    end
  end
end
