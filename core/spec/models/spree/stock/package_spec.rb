require 'spec_helper'

module Spree
  module Stock
    describe Package do
      let(:variant) { build(:variant, weight: 25.0) }
      let(:packer) { build(:stock_packer) }
      subject { Package.new(packer) }

      it 'calculates the weight of all the contents' do
        subject.add variant, 4
        subject.weight.should == 100.0
      end

      it 'filters by on_hand and backordered' do
        subject.add variant, 4, :on_hand
        subject.add variant, 3, :backordered
        subject.on_hand.count.should eq 1
        subject.backordered.count.should eq 1
      end

      it 'calcualtes the total number of items' do
        subject.add variant, 4
        subject.add variant, 3
        subject.quantity.should == 7
      end
    end
  end
end
