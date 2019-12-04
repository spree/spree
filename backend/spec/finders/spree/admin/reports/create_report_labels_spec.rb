require 'spec_helper'

describe Spree::Admin::Reports::CreateReportLabels do
  subject { described_class.new }

  context 'when mode is set to year' do
    it 'returns an array with years' do
      array = subject.call(
        from: Date.new(2008, 10, 12),
        to: Date.new(2015, 11, 20),
        mode: :year
      )

      expect(array).to eq %w[
        2008 2009 2010 2011 2012 2013 2014 2015
      ]
    end
  end

  context 'when mode is set to month' do
    it 'returns an array with years and months' do
      array = subject.call(
        from: Date.new(2014, 12, 12),
        to: Date.new(2015, 5, 20),
        mode: :month
      )

      expect(array).to eq %w[
        2014-12 2015-01 2015-02 2015-03 2015-04 2015-05
      ]
    end
  end

  context 'when mode is set to other value' do
    it 'returns an array of dates' do
      array = subject.call(
        from: Date.new(2014, 12, 28),
        to: Date.new(2015, 1, 1),
        mode: :day
      )

      expect(array).to eq %w[
        2014-12-28 2014-12-29 2014-12-30 2014-12-31 2015-01-01
      ]
    end
  end
end
