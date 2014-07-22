require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe Backordered do
        let(:variant) { build(:variant) }

        let(:packer) { build(:stock_packer) }

        subject { Backordered.new(packer) }

        it 'splits packages by status' do
          package = Package.new(packer.stock_location)
          4.times { package.add build(:inventory_unit, variant: variant) }
          5.times { package.add build(:inventory_unit, variant: variant), :backordered }

          packages = subject.split([package])
          packages.count.should eq 2
          packages.first.quantity.should eq 4
          packages.first.on_hand.count.should eq 4
          packages.first.backordered.count.should eq 0

          packages[1].contents.count.should eq 5
        end
      end
    end
  end
end
