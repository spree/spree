require 'spec_helper'

RSpec.describe Spree::Boolean do
  describe '.cast' do
    it 'reads the usual ways of writing yes as true' do
      [true, 1, 2.5, '1', 't', 'true', 'TRUE', ' on ', 'y', 'Yes', :yes].each do |value|
        expect(described_class.cast(value)).to be(true), "expected #{value.inspect} to be true"
      end
    end

    it 'reads everything else as false' do
      [false, nil, 0, 0.0, '', '0', 'f', 'false', 'off', 'n', 'no', 'maybe', :no, [], {}].each do |value|
        expect(described_class.cast(value)).to be(false), "expected #{value.inspect} to be false"
      end
    end
  end
end
