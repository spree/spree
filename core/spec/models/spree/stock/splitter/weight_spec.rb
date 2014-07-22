require 'spec_helper'

module Spree
  module Stock
    module Splitter
      describe Weight do
        let(:packer) { build(:stock_packer) }
        let(:variant) { build(:base_variant, :weight => 100) }

        subject { Weight.new(packer) }

        it 'splits and keeps splitting until all packages are underweight' do
          package = Package.new(packer.stock_location)
          4.times { package.add build(:inventory_unit, variant: variant) }
          packages = subject.split([package])
          packages.size.should eq 4
        end

        it 'handles packages that can not be reduced' do
          package = Package.new(packer.stock_location)
          variant.stub(:weight => 200)
          2.times { package.add build(:inventory_unit, variant: variant) }
          packages = subject.split([package])
          packages.size.should eq 2
        end
      end
    end
  end
end
