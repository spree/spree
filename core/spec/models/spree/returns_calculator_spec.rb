require 'spec_helper'

module Spree
  describe ReturnsCalculator do
    let(:return_item) { build(:return_item) }
    subject { ReturnsCalculator.new }

    it 'compute_shipment must be overridden' do
      expect {
        subject.compute(return_item)
      }.to raise_error
    end
  end
end
