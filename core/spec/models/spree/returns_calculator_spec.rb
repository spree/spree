require 'spec_helper'

module Spree
  describe ReturnsCalculator, type: :model do
    subject { ReturnsCalculator.new }

    let(:return_item) { build(:return_item) }

    it 'compute_shipment must be overridden' do
      expect do
        subject.compute(return_item)
      end.to raise_error(NotImplementedError)
    end
  end
end
